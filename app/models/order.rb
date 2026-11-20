class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :outbox_events, dependent: :destroy
  validates :idempotency_key, presence: true, uniqueness: true
  validates :email, presence: true
  validates :status, inclusion: { in: %w[confirmed cancelled] }
end
