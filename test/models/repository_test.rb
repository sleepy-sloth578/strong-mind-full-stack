require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  test "fresh? is false when never enriched" do
    repo = Repository.new(github_id: 1, fetched_at: nil)
    assert_not repo.fresh?
    assert repo.stale?
  end

  test "fresh? is true within the 24h window" do
    assert Repository.new(github_id: 1, fetched_at: 1.hour.ago).fresh?
    assert Repository.new(github_id: 1, fetched_at: 23.hours.ago).fresh?
  end

  test "fresh? is false past the 24h window" do
    assert_not Repository.new(github_id: 1, fetched_at: 25.hours.ago).fresh?
  end

  test "fresh and stale scopes" do
    fresh = Repository.create!(github_id: 1, fetched_at: 1.hour.ago)
    never = Repository.create!(github_id: 2, fetched_at: nil)
    old   = Repository.create!(github_id: 3, fetched_at: 2.days.ago)

    assert_equal [fresh], Repository.fresh.to_a
    assert_equal [never, old], Repository.stale.order(:github_id).to_a
  end

  test "github_id is unique at the database level" do
    Repository.create!(github_id: 42)
    assert_raises(ActiveRecord::RecordNotUnique) { Repository.create!(github_id: 42) }
  end

  test "cannot destroy a repository that still has push events" do
    repo  = Repository.create!(github_id: 500)
    actor = Actor.create!(github_id: 600)
    raw   = RawEvent.create!(github_event_id: "rx", event_type: "PushEvent", payload: {}, fetched_at: Time.current)
    PushEvent.create!(push_id: 9, repo_github_id: 500, actor_github_id: 600,
                      raw_event: raw, repository: repo, actor: actor)

    assert_raises(ActiveRecord::DeleteRestrictionError) { repo.destroy }
  end
end
