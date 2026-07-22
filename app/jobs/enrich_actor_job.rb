class EnrichActorJob < ApplicationJob
  queue_as :default

  def perform(actor_id)
    actor = Actor.find_by(id: actor_id)
    return unless actor&.stale?

    response = GithubEntitiesClient.fetch(actor.url)

    case response.status
    when 200
      data = response.body
      actor.update!(
        name:       data["name"],
        actor_type: data["type"],
        fetched_at: Time.current
      )
      Rails.logger.info("[enrich] actor #{actor.login} enriched")
    when 404
      actor.update!(fetched_at: Time.current)
      Rails.logger.warn("[enrich] actor #{actor.login} not found (404); marked attempted")
    when 403, 429
      Rails.logger.warn("[enrich] rate limited on actor #{actor.login}; left stale (resets #{response.rate_limit.reset_at})")
    else
      Rails.logger.error("[enrich] unexpected HTTP #{response.status} on actor #{actor.login}; left stale")
    end
  end
end
