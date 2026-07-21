require "test_helper"

class GithubEventsClientTest < ActiveSupport::TestCase
  FIRST_PAGE = "https://api.github.com/events?per_page=100".freeze
  SECOND_PAGE = "https://api.github.com/events?per_page=100&page=2".freeze

  test "paginates via Link header and accumulates events across pages" do
    stub_request(:get, FIRST_PAGE).to_return(
      status: 200,
      body: [ { "id" => "1", "type" => "PushEvent" } ].to_json,
      headers: {
        "ETag" => '"page1etag"',
        "Link" => %(<#{SECOND_PAGE}>; rel="next"),
        "X-RateLimit-Remaining" => "58",
        "X-RateLimit-Reset" => "1000"
      }
    )
    stub_request(:get, SECOND_PAGE).to_return(
      status: 200,
      body: [ { "id" => "2", "type" => "WatchEvent" } ].to_json,
      headers: { "X-RateLimit-Remaining" => "57", "X-RateLimit-Reset" => "1000" }
    )

    result = GithubEventsClient.fetch

    assert_equal %w[1 2], result.events.map { |e| e["id"] }
    assert_equal 2, result.pages_fetched
    assert_equal '"page1etag"', result.etag, "should capture the first page's ETag"
    assert_equal 57, result.rate_limit.remaining
    refute result.not_modified
    refute result.rate_limited
  end

  test "sends If-None-Match and returns not_modified on 304" do
    stub_request(:get, FIRST_PAGE)
      .with(headers: { "If-None-Match" => '"prior"' })
      .to_return(status: 304, headers: { "X-RateLimit-Remaining" => "59" })

    result = GithubEventsClient.fetch(etag: '"prior"')

    assert result.not_modified
    assert_empty result.events
    assert_equal '"prior"', result.etag
  end

  test "exits when rate limited with 403" do
    stub_request(:get, FIRST_PAGE).to_return(
      status: 403,
      headers: { "X-RateLimit-Remaining" => "0", "X-RateLimit-Reset" => "2000" }
    )

    result = GithubEventsClient.fetch

    assert_empty result.events
    assert result.rate_limited
    assert_equal 0, result.rate_limit.remaining
    assert_equal Time.at(2000), result.rate_limit.reset_at
  end

  test "stops after a page when the budget hits zero, even if more pages exist" do
    stub_request(:get, FIRST_PAGE).to_return(
      status: 200,
      body: [ { "id" => "1", "type" => "PushEvent" } ].to_json,
      headers: {
        "Link" => %(<#{SECOND_PAGE}>; rel="next"),
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => "3000"
      }
    )

    result = GithubEventsClient.fetch

    assert_equal %w[1], result.events.map { |e| e["id"] }
    assert_equal 1, result.pages_fetched
    assert result.rate_limited
    assert_not_requested :get, SECOND_PAGE
  end
end
