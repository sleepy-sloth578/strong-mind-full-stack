require "test_helper"

class PushEventTest < ActiveSupport::TestCase
  setup do
    @raw   = RawEvent.create!(github_event_id: "event1", event_type: "PushEvent", payload: {}, fetched_at: Time.current)
    @repo  = Repository.create!(github_id: 100)
    @actor = Actor.create!(github_id: 200)
  end

  def build_push_event(**attrs)
    PushEvent.new({
      push_id: 1, ref: "refs/heads/main", head: "abc", before: "def",
      repo_github_id: 100, actor_github_id: 200,
      raw_event: @raw, repository: @repo, actor: @actor
    }.merge(attrs))
  end

  test "valid with all associations present" do
    assert build_push_event.valid?
  end

  test "requires raw_event, repository, and actor" do
    push_event = PushEvent.new(push_id: 1, repo_github_id: 1, actor_github_id: 1)

    assert_not push_event.valid?
    assert push_event.errors.of_kind?(:raw_event, :blank)
    assert push_event.errors.of_kind?(:repository, :blank)
    assert push_event.errors.of_kind?(:actor, :blank)
  end

  test "push_id is unique at the database level" do
    build_push_event(push_id: 1).save!
    assert_raises(ActiveRecord::RecordNotUnique) { build_push_event(push_id: 1).save! }
  end
end
