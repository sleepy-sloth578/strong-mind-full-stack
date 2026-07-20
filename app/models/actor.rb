class Actor < ApplicationRecord
  include EnrichmentCache

  has_many :push_events, dependent: :restrict_with_exception
end
