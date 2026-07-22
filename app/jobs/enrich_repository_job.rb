class EnrichRepositoryJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    Rails.logger.info("[enrich] stub: would enrich repository #{repository_id}")
  end
end
