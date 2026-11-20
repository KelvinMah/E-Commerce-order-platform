require "rails_helper"

RSpec.describe "Catalog invalidation" do
  it "invalidates on product deletion" do
    product = Product.create!(name: "Remove", sku: SecureRandom.hex(10), stock: 2, price_cents: 200)
    expect(CatalogCache).to receive(:bump_version).at_least(:once)
    product.destroy!
  end

  it "does not invalidate on inventory-only updates" do
    product = Product.create!(name: "Inventory", sku: SecureRandom.hex(10), stock: 2, price_cents: 200)
    expect(CatalogCache).not_to receive(:bump_version)
    product.update!(stock: 1)
  end
end
