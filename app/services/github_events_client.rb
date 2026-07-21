require "net/http"
require "json"
class GithubEventsClient
  BASE_URL   = "https://api.github.com/events".freeze
  PER_PAGE   = 100
  MAX_PAGES  = 10
  USER_AGENT = "strong-mind-ingestion".freeze

  # events         : Array of raw event Hashes
  # not_modified   : true when the first page returned 304 (no new events)
  # etag           : first page's ETag, to persist for the next conditional fetch
  # rate_limit     : RateLimit from the last response seen
  # rate_limited   : true if we stopped early because the budget was exhausted
  # pages_fetched  : how many pages we actually read
  Result = Data.define(
    :events, :not_modified, :etag, :rate_limit, :rate_limited, :pages_fetched
  )

  RateLimit = Data.define(:limit, :remaining, :reset_at) do
    def exhausted?
      remaining && remaining <= 0
    end
  end

  class << self
    def fetch(etag: nil)
      url           = "#{BASE_URL}?per_page=#{PER_PAGE}"
      events        = []
      page_etag     = etag
      rate_limit    = nil
      rate_limited  = false
      pages_fetched = 0

      while url && pages_fetched < MAX_PAGES
        first_page = pages_fetched.zero?
        response   = get(URI(url), etag: (first_page ? etag : nil))
        rate_limit = rate_limit_from(response)
        code       = response.code.to_i

        case code
        when 304
          Rails.logger.info("[client] 304 Not Modified — no new events (no budget spent)")
          return Result.new(
            events: [], not_modified: true, etag: etag, rate_limit: rate_limit,
            rate_limited: false, pages_fetched: pages_fetched
          )
        when 200
          pages_fetched += 1
          page_etag = response["etag"] if first_page
          events.concat(Array(JSON.parse(response.body)))
          Rails.logger.info("[client] page #{pages_fetched}: +#{events.size} events; remaining=#{rate_limit.remaining}")
        when 403, 429
          rate_limited = true
          Rails.logger.warn("[client] rate limited (HTTP #{code}); stopping. resets at #{rate_limit.reset_at}")
          break
        else
          Rails.logger.error("[client] unexpected HTTP #{code}; stopping")
          break
        end

        if rate_limit.exhausted?
          rate_limited = true
          Rails.logger.warn("[client] rate budget exhausted; stopping. resets at #{rate_limit.reset_at}")
          break
        end

        url = next_url(response)
      end

      Result.new(
        events: events, not_modified: false, etag: page_etag, rate_limit: rate_limit,
        rate_limited: rate_limited, pages_fetched: pages_fetched
      )
    end

    private

    def get(uri, etag: nil)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"]    = USER_AGENT
      request["If-None-Match"] = etag if etag

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10
      http.request(request)
    end

    def rate_limit_from(response)
      reset = response["x-ratelimit-reset"]
      RateLimit.new(
        limit:     response["x-ratelimit-limit"]&.to_i,
        remaining: response["x-ratelimit-remaining"]&.to_i,
        reset_at:  reset ? Time.at(reset.to_i) : nil
      )
    end

    def next_url(response)
      link = response["link"]
      return nil unless link

      link.split(",").each do |part|
        url_segment, *params = part.split(";")
        next unless params.any? { |p| p.include?('rel="next"') }

        return url_segment[/<(.+)>/, 1]
      end
      nil
    end
  end
end
