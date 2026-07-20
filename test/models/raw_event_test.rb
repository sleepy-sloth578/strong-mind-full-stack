require "test_helper"

class RawEventTest < ActiveSupport::TestCase
  def create_raw(id, **attrs)
    RawEvent.create!(
      { github_event_id: id, event_type: "PushEvent", payload: {}, fetched_at: Time.current }.merge(attrs)
    )
  end

  test "defaults to pending status" do
    assert create_raw("event1").pending?
  end

  test "status scopes" do
    pending   = create_raw("event-pending")
    processed = create_raw("event-processed", status: :processed)
    failed    = create_raw("evebt-failed", status: :failed, error: "boom")

    assert_equal [pending],   RawEvent.pending.to_a
    assert_equal [processed], RawEvent.processed.to_a
    assert_equal [failed],    RawEvent.failed.to_a
  end

  test "github_event_id is unique at the database level" do
    create_raw("dup")
    assert_raises(ActiveRecord::RecordNotUnique) { create_raw("dup") }
  end
end
