class EnrichActorJob < ApplicationJob
  queue_as :default

  def perform(actor_id)
    Rails.logger.info("[enrich] stub: would enrich actor #{actor_id}")
  end
end
