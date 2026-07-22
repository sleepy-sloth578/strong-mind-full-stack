class EnrichRepositoryJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find_by(id: repository_id)
    return unless repository&.stale?

    response = GithubEntitiesClient.fetch(repository.url)

    case response.status
    when 200
      data = response.body
      repository.update!(
        description:      data["description"],
        language:         data["language"],
        stargazers_count: data["stargazers_count"],
        forks_count:      data["forks_count"],
        fetched_at:       Time.current
      )
      Rails.logger.info("[enrich] repository #{repository.full_name} enriched")
    when 404
      repository.update!(fetched_at: Time.current)
      Rails.logger.warn("[enrich] repository #{repository.full_name} not found (404); marked attempted")
    when 403, 429
      Rails.logger.warn("[enrich] rate limited on repository #{repository.full_name}; left stale (resets #{response.rate_limit.reset_at})")
    else
      Rails.logger.error("[enrich] unexpected HTTP #{response.status} on repository #{repository.full_name}; left stale")
    end
  end
end
