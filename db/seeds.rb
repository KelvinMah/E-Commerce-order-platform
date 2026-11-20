require "securerandom"
count = Integer(ENV.fetch("PRODUCT_COUNT", "100"))
puts "Seeding #{count} products..."
count.times.each_slice(1_000) do |batch|
  rows = batch.map do |i|
    { sku: "SKU-#{i.to_s.rjust(6, '0')}", name: "Product #{i} #{%w[Desk Chair Lamp Keyboard Monitor].fetch(i % 5)}",
      description: "Quality catalog item ##{i}", price_cents: 999 + (i * 37) % 90_000,
      stock: 10 + i % 90, active: true, created_at: Time.current, updated_at: Time.current }
  end
  Product.upsert_all(rows, unique_by: :index_products_on_sku)
end
CatalogCache.bump_version
puts "Done"
