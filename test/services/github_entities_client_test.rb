require "test_helper"

class GithubEntitiesClientTest < ActiveSupport::TestCase
  REPO_URL = "https://api.github.com/repos/rails/rails".freeze
  USER_URL = "https://api.github.com/users/octocat".freeze

  test "fetch returns status, parsed body, and rate limit" do
    stub_request(:get, REPO_URL).to_return(
      status: 200,
      body: { "language" => "Ruby", "stargazers_count" => 100 }.to_json,
      headers: { "X-RateLimit-Remaining" => "42", "X-RateLimit-Reset" => "1000" }
    )

    response = GithubEntitiesClient.fetch(REPO_URL)

    assert_equal 200, response.status
    assert_equal "Ruby", response.body["language"]
    assert_equal 100, response.body["stargazers_count"]
    assert_equal 42, response.rate_limit.remaining
    assert_equal Time.at(1000), response.rate_limit.reset_at
  end

  test "fetch follows the given URL and returns the parsed body" do
    stub_request(:get, USER_URL).to_return(
      status: 200,
      body: { "name" => "The Octocat", "type" => "User" }.to_json,
      headers: { "X-RateLimit-Remaining" => "40" }
    )

    response = GithubEntitiesClient.fetch(USER_URL)

    assert_equal 200, response.status
    assert_equal "The Octocat", response.body["name"]
    assert_equal "User", response.body["type"]
  end

  test "404 status" do
    stub_request(:get, REPO_URL).to_return(status: 404, body: "")

    response = GithubEntitiesClient.fetch(REPO_URL)

    assert_equal 404, response.status
    assert_nil response.body
  end

  test "rate-limit responses (403) with the reset time" do
    stub_request(:get, USER_URL).to_return(
      status: 403,
      headers: { "X-RateLimit-Remaining" => "0", "X-RateLimit-Reset" => "2000" }
    )

    response = GithubEntitiesClient.fetch(USER_URL)

    assert_equal 403, response.status
    assert_equal 0, response.rate_limit.remaining
    assert_equal Time.at(2000), response.rate_limit.reset_at
  end

  test "degrades gracefully to status 0 on an invalid URL (e.g. bot login)" do
    response = GithubEntitiesClient.fetch("https://api.github.com/users/github-actions[bot]")

    assert_equal 0, response.status
    assert_nil response.body
  end

  test "degrades gracefully to status 0 on a blank/nil URL" do
    assert_equal 0, GithubEntitiesClient.fetch(nil).status
    assert_equal 0, GithubEntitiesClient.fetch("").status
  end

  test "returns a nil body on malformed JSON" do
    stub_request(:get, REPO_URL).to_return(status: 200, body: "not json{")

    response = GithubEntitiesClient.fetch(REPO_URL)

    assert_equal 200, response.status
    assert_nil response.body
  end
end
