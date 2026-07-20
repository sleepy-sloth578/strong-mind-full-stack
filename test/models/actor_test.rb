require "test_helper"

class ActorTest < ActiveSupport::TestCase
  test "includes enrichment cache" do
    assert_not Actor.new(github_id: 1, fetched_at: nil).fresh?
    assert Actor.new(github_id: 1, fetched_at: 30.minutes.ago).fresh?
    assert Actor.new(github_id: 1, fetched_at: 2.days.ago).stale?
  end

  test "fresh and stale scopes" do
    fresh = Actor.create!(github_id: 1, login: "joe", fetched_at: 1.hour.ago)
    stale = Actor.create!(github_id: 2, login: "smith", fetched_at: nil)

    assert_includes Actor.fresh, fresh
    assert_includes Actor.stale, stale
    assert_not_includes Actor.fresh, stale
  end

  test "github_id is unique at the database level" do
    Actor.create!(github_id: 7, login: "carl")
    assert_raises(ActiveRecord::RecordNotUnique) { Actor.create!(github_id: 7, login: "jose") }
  end

  test "cannot destroy an actor that still has push events" do
    repo  = Repository.create!(github_id: 501)
    actor = Actor.create!(github_id: 601)
    raw   = RawEvent.create!(github_event_id: "ry", event_type: "PushEvent", payload: {}, fetched_at: Time.current)
    PushEvent.create!(push_id: 10, repo_github_id: 501, actor_github_id: 601,
                      raw_event: raw, repository: repo, actor: actor)

    assert_raises(ActiveRecord::DeleteRestrictionError) { actor.destroy }
  end
end
