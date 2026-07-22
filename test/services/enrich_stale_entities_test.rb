require "test_helper"

class EnrichStaleEntitiesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def stale_repo(github_id, created_at: Time.current)
    Repository.create!(github_id: github_id, created_at: created_at)
  end

  def stale_actor(github_id)
    Actor.create!(github_id: github_id, login: "user#{github_id}")
  end

  test "enqueues repo and actor jobs for stale entities" do
    repo  = stale_repo(1)
    actor = stale_actor(2)

    count = EnrichStaleEntities.new(remaining: 60).call

    assert_equal 2, count
    assert_enqueued_with(job: EnrichRepositoryJob, args: [ repo.id ])
    assert_enqueued_with(job: EnrichActorJob, args: [ actor.id ])
  end

  test "skips fresh entities" do
    Repository.create!(github_id: 1, fetched_at: Time.current)
    stale_actor(2)

    count = EnrichStaleEntities.new(remaining: 60).call

    assert_equal 1, count
    assert_no_enqueued_jobs only: EnrichRepositoryJob
    assert_enqueued_jobs 1, only: EnrichActorJob
  end

  test "caps the enqueues to remaining minus the reserve floor" do
    11.times { |i| stale_repo(100 + i) }
    11.times { |i| stale_actor(200 + i) }

    count = EnrichStaleEntities.new(remaining: 9).call

    assert_equal 4, count
    assert_enqueued_jobs 4, only: [ EnrichRepositoryJob, EnrichActorJob ]
  end

  test "enqueues nothing when budget is at or below the floor" do
    stale_repo(1)
    stale_actor(2)

    assert_equal 0, EnrichStaleEntities.new(remaining: 5).call
    assert_equal 0, EnrichStaleEntities.new(remaining: 0).call
    assert_no_enqueued_jobs
  end

  test "treats nil remaining as no budget" do
    stale_repo(1)
    assert_equal 0, EnrichStaleEntities.new(remaining: nil).call
  end

  test "drains oldest (deferred) entities first" do
    old = stale_repo(1, created_at: 2.days.ago)
    stale_repo(2, created_at: 1.hour.ago)

    EnrichStaleEntities.new(remaining: 7).call

    assert_enqueued_jobs 1, only: EnrichRepositoryJob
    assert_enqueued_with(job: EnrichRepositoryJob, args: [ old.id ])
  end
end
