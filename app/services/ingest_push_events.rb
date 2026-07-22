# Orchestrates one ingestion cycle: fetch GitHub events, keep PushEvents,
# persist them (raw + structured), and enqueue enrichment
class IngestPushEvents
  def initialize
    @stats = { fetched: 0, push_events: 0, persisted: 0, failed: 0, enqueued: 0 }
  end

  def call
    started_at = Time.current
    Rails.logger.info("[ingest] starting one ingestion cycle")

    result = fetch
    return report(started_at) unless result

    if result.not_modified
      Rails.logger.info("[ingest] no new events (304 Not Modified)")
    else
      persist_new_events(result)
    end

    @stats[:enqueued] = EnrichStaleEntities.new(remaining: result.rate_limit&.remaining).call
    report(started_at)
  end

  private

  def persist_new_events(result)
    @stats[:fetched]     = result.events.size
    push_events          = result.events.select { |event| event["type"] == "PushEvent" }
    @stats[:push_events] = push_events.size

    push_events.each { |event| ingest_one(event) }

    Rails.logger.warn("[ingest] rate budget low; enrichment for some entities deferred") if result.rate_limited
  end

  def fetch
    GithubEventsClient.fetch
  rescue StandardError => e
    Rails.logger.error("[ingest] fetch failed: #{e.class}: #{e.message}")
    nil
  end

  def ingest_one(event)
    raw = persist_raw(event)
    extract(event, raw)
    @stats[:persisted] += 1
  rescue StandardError => e
    raw&.update(status: :failed, error: "#{e.class}: #{e.message}")
    @stats[:failed] += 1
    Rails.logger.error("[ingest] event #{event['id'].inspect} failed extraction: #{e.class}: #{e.message}")
  end

  def persist_raw(event)
    RawEvent.create_or_find_by!(github_event_id: event.fetch("id")) do |raw|
      raw.event_type = event["type"]
      raw.payload    = event
      raw.fetched_at = Time.current
    end
  end

  def extract(event, raw)
    payload    = event.fetch("payload")
    repository = upsert_repository(event.fetch("repo"))
    actor      = upsert_actor(event.fetch("actor"))
    upsert_push_event(payload, raw, repository, actor)

    raw.processed! unless raw.processed?
  end

  def upsert_repository(repo)
    Repository.create_or_find_by!(github_id: repo.fetch("id")) do |repository|
      repository.full_name = repo["name"]
    end
  end

  def upsert_actor(actor)
    Actor.create_or_find_by!(github_id: actor.fetch("id")) do |record|
      record.login      = actor["login"]
      record.avatar_url = actor["avatar_url"]
    end
  end

  def upsert_push_event(payload, raw, repository, actor)
    PushEvent.create_or_find_by!(push_id: payload.fetch("push_id")) do |push_event|
      push_event.ref             = payload["ref"]
      push_event.head            = payload["head"]
      push_event.before          = payload["before"]
      push_event.repo_github_id  = repository.github_id
      push_event.actor_github_id = actor.github_id
      push_event.raw_event       = raw
      push_event.repository      = repository
      push_event.actor           = actor
    end
  end

  def report(started_at)
    elapsed = (Time.current - started_at).round(3)
    Rails.logger.info("[ingest] done in #{elapsed}s — #{@stats}")
    @stats
  end
end
