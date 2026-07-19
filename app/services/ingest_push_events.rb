class IngestPushEvents
  def initialize(logger: Rails.logger)
    @logger = logger
  end

  def call
    started_at = Time.current
    log("starting one ingestion cycle")
    elapsed = (Time.current - started_at).round(3)
    log("done in #{elapsed}s")
  end

  private

  def log(message)
    @logger.info("[ingest] #{message}")
  end
end
