require "net/http"
require "json"
class GithubEntitiesClient
  BASE_URL   = "https://api.github.com".freeze
  USER_AGENT = "strong-mind-ingestion".freeze

  Response  = Data.define(:status, :body, :rate_limit)
  RateLimit = Data.define(:remaining, :reset_at)

  class << self
    def fetch_repository(full_name)
      get("/repos/#{full_name}")
    end

    def fetch_user(login)
      get("/users/#{login}")
    end

    private

    def get(path)
      uri     = URI("#{BASE_URL}#{path}")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = 5
      http.read_timeout = 10
      response = http.request(request)

      Response.new(
        status:     response.code.to_i,
        body:       parse(response.body),
        rate_limit: rate_limit_from(response)
      )
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      Rails.logger.error("[github] GET #{path} failed: #{e.class}: #{e.message}")
      Response.new(status: 0, body: nil, rate_limit: RateLimit.new(remaining: nil, reset_at: nil))
    end

    def parse(body)
      body.present? ? JSON.parse(body) : nil
    rescue JSON::ParserError
      nil
    end

    def rate_limit_from(response)
      reset = response["x-ratelimit-reset"]
      RateLimit.new(
        remaining: response["x-ratelimit-remaining"]&.to_i,
        reset_at:  reset ? Time.at(reset.to_i) : nil
      )
    end
  end
end
