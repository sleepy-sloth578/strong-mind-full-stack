class RawEvent < ApplicationRecord
  enum :status, { pending: "pending", processed: "processed", failed: "failed" }, default: "pending"

  has_one :push_event, dependent: :destroy
end
