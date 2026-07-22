require "test_helper"

class EnrichActorJobTest < ActiveSupport::TestCase
  USER_URL = "https://api.github.com/users/octocat".freeze

  def actor(**attrs)
    Actor.create!({ github_id: 200, login: "octocat", url: USER_URL }.merge(attrs))
  end

  def stub_user(status:, body: {}, remaining: "50")
    stub_request(:get, USER_URL).to_return(
      status: status, body: body.to_json,
      headers: { "X-RateLimit-Remaining" => remaining, "X-RateLimit-Reset" => "1000" }
    )
  end

  test "enriches a stale actor from the API and marks it fresh" do
    a = actor
    stub_user(status: 200, body: { "name" => "The Octocat", "type" => "User" })

    EnrichActorJob.perform_now(a.id)

    a.reload
    assert_equal "The Octocat", a.name
    assert_equal "User", a.actor_type
    assert a.fresh?
  end

  test "skips a fresh actor without calling the API" do
    a = actor(fetched_at: Time.current)

    EnrichActorJob.perform_now(a.id)

    assert_not_requested :get, USER_URL
  end

  test "marks a 404 actor as attempted (fresh, but no details)" do
    a = actor
    stub_user(status: 404)

    EnrichActorJob.perform_now(a.id)

    a.reload
    assert_nil a.name
    assert a.fresh?
  end

  test "leaves the actor stale when rate limited (429)" do
    a = actor
    stub_user(status: 429, remaining: "0")

    EnrichActorJob.perform_now(a.id)

    a.reload
    assert_nil a.fetched_at
    assert a.stale?
  end
end
