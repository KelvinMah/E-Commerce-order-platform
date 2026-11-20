# Run: bundle exec rails runner scripts/benchmark_catalog.rb
require "json"
queries = 0
subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  payload = args.last
  queries += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name])
end
begin
  uncached = []
  5.times do |i|
    queries = 0
    Product.available.order(:id).limit(20).to_a.map { |p| [p.id, p.name, p.price_cents] }
    uncached << queries
  end
  queries = 0
  5.times { CatalogCache.fetch("benchmark:catalog", ttl: 60) { Product.available.order(:id).limit(20).map { |p| { id: p.id, name: p.name } } } }
  puts JSON.pretty_generate({ uncached_query_counts: uncached, cached_total_db_queries_five_calls: queries, note: "Baseline must be measured separately; not evidence of a 72% reduction." })
ensure
  ActiveSupport::Notifications.unsubscribe(subscriber)
end
