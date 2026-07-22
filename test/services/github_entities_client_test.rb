require "test_helper"

class GithubEntitiesClientTest < ActiveSupport::TestCase
  REPO_URL = "https://api.github.com/repos/rails/rails".freeze
  USER_URL = "https://api.github.com/users/octocat".freeze

  test "fetch_repository returns metadata" do
    stub_request(:get, REPO_URL).to_return(
      status: 200,
      body: { "language" => "Ruby", "stargazers_count" => 100 }.to_json,
      headers: { "X-RateLimit-Remaining" => "42", "X-RateLimit-Reset" => "1000" }
    )

    response = GithubEntitiesClient.fetch_repository("rails/rails")

    assert_equal 200, response.status
    assert_equal "Ruby", response.body["language"]
    assert_equal 100, response.body["stargazers_count"]
    assert_equal 42, response.rate_limit.remaining
    assert_equal Time.at(1000), response.rate_limit.reset_at
  end

  test "fetch_user hits /users and returns the parsed body" do
    stub_request(:get, USER_URL).to_return(
      status: 200,
      body: { "name" => "The Octocat", "type" => "User" }.to_json,
      headers: { "X-RateLimit-Remaining" => "40" }
    )

    response = GithubEntitiesClient.fetch_user("octocat")

    assert_equal 200, response.status
    assert_equal "The Octocat", response.body["name"]
    assert_equal "User", response.body["type"]
  end

  test "url-encodes special characters in the path (e.g. bot logins)" do
    encoded = stub_request(:get, "https://api.github.com/users/github-actions%5Bbot%5D")
      .to_return(status: 200, body: { "type" => "Bot" }.to_json)

    response = GithubEntitiesClient.fetch_user("github-actions[bot]")

    assert_requested encoded
    assert_equal 200, response.status
  end

  test "surfaces a 404 status" do
    stub_request(:get, REPO_URL).to_return(status: 404, body: "")

    response = GithubEntitiesClient.fetch_repository("rails/rails")

    assert_equal 404, response.status
    assert_nil response.body
  end

  test "surfaces rate-limit responses (403) with the reset time" do
    stub_request(:get, USER_URL).to_return(
      status: 403,
      headers: { "X-RateLimit-Remaining" => "0", "X-RateLimit-Reset" => "2000" }
    )

    response = GithubEntitiesClient.fetch_user("octocat")

    assert_equal 403, response.status
    assert_equal 0, response.rate_limit.remaining
    assert_equal Time.at(2000), response.rate_limit.reset_at
  end

  test "degrades gracefully to status 0 on a transport failure" do
    stub_request(:get, REPO_URL).to_timeout

    response = GithubEntitiesClient.fetch_repository("rails/rails")

    assert_equal 0, response.status
    assert_nil response.body
  end

  test "returns a nil body on malformed JSON" do
    stub_request(:get, REPO_URL).to_return(status: 200, body: "not json{")

    response = GithubEntitiesClient.fetch_repository("rails/rails")

    assert_equal 200, response.status
    assert_nil response.body
  end
end
