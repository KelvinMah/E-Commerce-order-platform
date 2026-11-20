require "connection_pool"
class CatalogCache
  PREFIX = "catalog:v2".freeze
  POOL = ConnectionPool.new(size: Integer(ENV.fetch("CATALOG_REDIS_POOL", "10")), timeout: 2) do
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"), connect_timeout: 1, read_timeout: 1)
  end

  def self.with_redis(&block)
    POOL.with(&block)
  end

  def self.version
    with_redis { |redis| redis.get("#{PREFIX}:version") || "0" }
  rescue Redis::BaseError, ConnectionPool::TimeoutError
    nil
  end

  def self.bump_version
    with_redis { |redis| redis.incr("#{PREFIX}:version") }
  rescue Redis::BaseError, ConnectionPool::TimeoutError => e
    Rails.logger.warn("Catalog invalidation unavailable: #{e.message}")
  end

  def self.fetch(key, ttl: 10)
    current_version = version
    return yield unless current_version
    cache_key = "#{PREFIX}:#{current_version}:#{key}"
    cached = with_redis { |redis| redis.get(cache_key) }
    return JSON.parse(cached) if cached
    result = yield
    with_redis { |redis| redis.set(cache_key, JSON.generate(result), ex: ttl) }
    result
  rescue Redis::BaseError, ConnectionPool::TimeoutError => e
    Rails.logger.warn("Catalog cache unavailable: #{e.message}")
    result || yield
  end
end
