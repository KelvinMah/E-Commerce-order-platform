class Product < ApplicationRecord
  validates :name, :sku, presence: true
  validates :sku, uniqueness: true
  validates :stock, numericality: { greater_than_or_equal_to: 0 }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  has_many :order_items, dependent: :restrict_with_exception
  scope :available, -> { where(active: true) }

  # Inventory changes are high-frequency and must not flush the entire catalog.
  # Listing stock is indicative; checkout always checks locked DB inventory.
  after_commit :invalidate_catalog_metadata, on: [:create, :update, :destroy]

  private
  def invalidate_catalog_metadata
    return if !destroyed? && previous_changes.keys.all? { |key| %w[stock updated_at].include?(key) }
    CatalogCache.bump_version
  end
end
