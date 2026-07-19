namespace :ingest do
  desc "Run one GitHub PushEvent ingestion cycle"
  task run: :environment do
    IngestPushEvents.new.call
  end
end
