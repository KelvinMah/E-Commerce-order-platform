class DeliveryReceipt < ApplicationRecord
  belongs_to :outbox_event
end
