# Run with CHECKOUT_COUNT=200 bundle exec rails runner scripts/benchmark_checkout.rb
require "securerandom"
require "json"
n = Integer(ENV.fetch("CHECKOUT_COUNT", "200"))
p = Product.create!(name: "Benchmark", sku: SecureRandom.hex(12), price_cents: 100, stock: n + 10)
times = n.times.map do |i|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  CheckoutService.new(email: "benchmark@example.com", idempotency_key: "bench-#{p.id}-#{i}", items: [{ product_id: p.id, quantity: 1 }]).call
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
end.sort
puts JSON.pretty_generate({ count: n, p50_ms: times[(n*0.50).floor].round(2), p95_ms: times[[(n*0.95).ceil-1,n-1].min].round(2), p99_ms: times[[(n*0.99).ceil-1,n-1].min].round(2) })
