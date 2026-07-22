require "test_helper"

class EnrichRepositoryJobTest < ActiveSupport::TestCase
  REPO_URL = "https://api.github.com/repos/rails/rails".freeze

  def repository(**attrs)
    Repository.create!({ github_id: 100, full_name: "rails/rails" }.merge(attrs))
  end

  def stub_repo(status:, body: {}, remaining: "50")
    stub_request(:get, REPO_URL).to_return(
      status: status, body: body.to_json,
      headers: { "X-RateLimit-Remaining" => remaining, "X-RateLimit-Reset" => "1000" }
    )
  end

  test "enriches a stale repository from the API and marks it fresh" do
    repo = repository
    stub_repo(status: 200, body: {
      "description" => "Ruby on Rails", "language" => "Ruby",
      "stargazers_count" => 56_000, "forks_count" => 21_000
    })

    EnrichRepositoryJob.perform_now(repo.id)

    repo.reload
    assert_equal "Ruby on Rails", repo.description
    assert_equal "Ruby", repo.language
    assert_equal 56_000, repo.stargazers_count
    assert_equal 21_000, repo.forks_count
    assert repo.fresh?
  end

  test "skips a fresh repository without calling the API" do
    repo = repository(fetched_at: Time.current)

    EnrichRepositoryJob.perform_now(repo.id)

    assert_not_requested :get, REPO_URL
  end

  test "marks a 404 repository as attempted (fresh, but no details)" do
    repo = repository
    stub_repo(status: 404)

    EnrichRepositoryJob.perform_now(repo.id)

    repo.reload
    assert_nil repo.description
    assert repo.fresh?, "fetched_at is set so we don't retry a gone repo every cycle"
  end

  test "leaves the repository stale when rate limited (403)" do
    repo = repository
    stub_repo(status: 403, remaining: "0")

    EnrichRepositoryJob.perform_now(repo.id)

    repo.reload
    assert_nil repo.fetched_at
    assert repo.stale?
  end

  test "does nothing when the repository no longer exists" do
    assert_nothing_raised { EnrichRepositoryJob.perform_now(-1) }
    assert_not_requested :get, REPO_URL
  end
end
