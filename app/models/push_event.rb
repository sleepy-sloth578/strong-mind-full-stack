class PushEvent < ApplicationRecord
  belongs_to :raw_event
  belongs_to :repository
  belongs_to :actor
end
