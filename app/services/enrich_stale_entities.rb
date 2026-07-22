# Pull-based enrichment: enqueue jobs for stale repositories/actors up to the
# rate budget, oldest first so entities deferred by earlier runs are continued
# before newly-created ones.
# Each enrichment job has a shared rate limit budget
class EnrichStaleEntities
  RESERVE_FLOOR = 5
  def initialize(remaining:)
    @budget = [ remaining.to_i - RESERVE_FLOOR, 0 ].max
  end

  def call
    return 0 if @budget.zero?

    repo_budget  = (@budget / 2.0).ceil
    actor_budget = @budget - repo_budget

    enqueue(Repository.stale.order(:created_at).limit(repo_budget), EnrichRepositoryJob) +
      enqueue(Actor.stale.order(:created_at).limit(actor_budget), EnrichActorJob)
  end

  private

  def enqueue(scope, job)
    count = 0
    scope.each do |record|
      job.perform_later(record.id)
      count += 1
    end
    count
  end
end
