class OutboxEvent < ApplicationRecord
  belongs_to :order
  has_one :delivery_receipt, dependent: :destroy
  validates :kind, inclusion: { in: %w[confirmation receipt inventory_sync] }
  validates :kind, uniqueness: { scope: :order_id }
end
