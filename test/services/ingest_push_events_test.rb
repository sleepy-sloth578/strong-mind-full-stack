require "test_helper"

class IngestPushEventsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  EVENTS_URL = "#{GithubEventsClient::BASE_URL}?per_page=#{GithubEventsClient::PER_PAGE}".freeze

  def push_event_json(id:, push_id:, repo_id:, actor_id:)
    {
      "id" => id, "type" => "PushEvent",
      "actor" => {
        "id" => actor_id, "login" => "octocat", "avatar_url" => "https://avatars/#{actor_id}",
        "url" => "https://api.github.com/users/octocat"
      },
      "repo"  => {
        "id" => repo_id, "name" => "org/repo-#{repo_id}",
        "url" => "https://api.github.com/repos/org/repo-#{repo_id}"
      },
      "payload" => {
        "push_id" => push_id, "ref" => "refs/heads/main",
        "head" => "head#{push_id}", "before" => "before#{push_id}"
      }
    }
  end

  def stub_events(events)
    stub_request(:get, EVENTS_URL).to_return(
      status: 200,
      body: events.to_json,
      headers: { "X-RateLimit-Remaining" => "50", "X-RateLimit-Reset" => "1000" }
    )
  end

  test "persists raw, structured push event" do
    stub_events([ push_event_json(id: "1", push_id: 10, repo_id: 100, actor_id: 200) ])

    IngestPushEvents.new.call

    raw = RawEvent.sole # aka assert_equal 1, RawEvent.count
    assert raw.processed?
    assert_equal "PushEvent", raw.event_type
    assert_equal "1", raw.github_event_id

    push = PushEvent.sole
    assert_equal 10, push.push_id
    assert_equal "refs/heads/main", push.ref
    assert_equal raw, push.raw_event

    repo = Repository.sole
    assert_equal 100, repo.github_id
    assert_equal "org/repo-100", repo.full_name
    assert_equal "https://api.github.com/repos/org/repo-100", repo.url # payload-provided URL captured
    assert_nil repo.fetched_at
    assert repo.stale?

    actor = Actor.sole
    assert_equal "octocat", actor.login
    assert_equal "https://api.github.com/users/octocat", actor.url
    assert_nil actor.fetched_at
  end

  test "ignores non-PushEvents" do
    stub_events([
      push_event_json(id: "1", push_id: 10, repo_id: 100, actor_id: 200),
      { "id" => "2", "type" => "WatchEvent", "actor" => { "id" => 1 }, "repo" => { "id" => 2 }, "payload" => {} }
    ])

    stats = IngestPushEvents.new.call

    assert_equal 2, stats[:fetched]
    assert_equal 1, stats[:push_events]
    assert_equal 1, RawEvent.count, "only the PushEvent is persisted"
    assert_equal 1, PushEvent.count
  end

  test "is idempotent across re-runs (no dups)" do
    stub_events([ push_event_json(id: "1", push_id: 10, repo_id: 100, actor_id: 200) ])

    IngestPushEvents.new.call
    IngestPushEvents.new.call

    assert_equal 1, RawEvent.count
    assert_equal 1, PushEvent.count
    assert_equal 1, Repository.count
    assert_equal 1, Actor.count
  end

  test "does not overwrite an already-enriched repo" do
    Repository.create!(
      github_id: 100, full_name: "org/repo-100",
      description: "enriched!", language: "Ruby", fetched_at: Time.current
    )

    stub_events([ push_event_json(id: "1", push_id: 10, repo_id: 100, actor_id: 200) ])
    IngestPushEvents.new.call

    repo = Repository.find_by(github_id: 100)
    assert_equal "enriched!", repo.description, "ingest must not overwrite enriched data"
    assert_equal "Ruby", repo.language
    assert repo.fresh?, "fetched_at must not be reset"
  end

  test "marks a malformed event failed and continues with the rest" do
    good = push_event_json(id: "1", push_id: 10, repo_id: 100, actor_id: 200)
    bad  = {
      "id" => "2", "type" => "PushEvent",
      "actor" => { "id" => 201, "login" => "x" }, "repo" => { "id" => 101, "name" => "o/r" },
      "payload" => {}
    }
    stub_events([ bad, good ])

    stats = IngestPushEvents.new.call

    assert_equal 2, RawEvent.count
    assert_equal 1, PushEvent.count
    assert_equal 1, stats[:persisted]
    assert_equal 1, stats[:failed]

    failed = RawEvent.failed.sole
    assert_equal "2", failed.github_event_id
    assert failed.error.present?
  end

  test "triggers enrichment for stale entities after ingest" do
    stub_events([ push_event_json(id: "1", push_id: 10, repo_id: 100, actor_id: 200) ])

    stats = IngestPushEvents.new.call

    assert_equal 2, stats[:enqueued]
    assert_enqueued_with(job: EnrichRepositoryJob, args: [ Repository.find_by(github_id: 100).id ])
    assert_enqueued_with(job: EnrichActorJob, args: [ Actor.find_by(github_id: 200).id ])
  end

  test "does nothing on a 304 not_modified response" do
    stub_request(:get, EVENTS_URL).to_return(
      status: 304, headers: { "X-RateLimit-Remaining" => "59" }
    )

    stats = IngestPushEvents.new.call

    assert_equal 0, RawEvent.count
    assert_equal 0, stats[:fetched]
  end

  test "still drains the stale backlog on a 304 (continues deferred entities)" do
    Repository.create!(github_id: 999) # fetched_at nil => stale, from a prior run
    stub_request(:get, EVENTS_URL).to_return(
      status: 304, headers: { "X-RateLimit-Remaining" => "59" }
    )

    assert_enqueued_with(job: EnrichRepositoryJob, args: [ Repository.find_by(github_id: 999).id ]) do
      IngestPushEvents.new.call
    end
  end
end
