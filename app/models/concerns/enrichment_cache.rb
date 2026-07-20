module EnrichmentCache
  extend ActiveSupport::Concern
  FRESHNESS_WINDOW = 24.hours

  included do
    scope :stale, -> { where(fetched_at: nil).or(where(fetched_at: ..FRESHNESS_WINDOW.ago)) }
    scope :fresh, -> { where.not(fetched_at: nil).where(fetched_at: FRESHNESS_WINDOW.ago..) }
  end

  def fresh?
    fetched_at.present? && fetched_at > FRESHNESS_WINDOW.ago
  end

  def stale?
    !fresh?
  end
end
