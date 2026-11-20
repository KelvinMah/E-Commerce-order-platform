module Api
  class ProductsController < ApplicationController
    def index
      page = [[params.fetch(:page, 1).to_i, 1].max, 100_000].min
      limit = [[params.fetch(:limit, 20).to_i, 1].max, 100].min
      query = params[:q].to_s.strip
      raise ActionController::BadRequest, "Search too long" if query.length > 100
      # Cache only the first 10 pages of non-search results; metadata changes invalidate the version; stock has a short TTL.
      loader = lambda do
        scope = Product.available.order(:id)
        scope = scope.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") unless query.empty?
        records = scope.offset((page - 1) * limit).limit(limit + 1).to_a
        { products: records.first(limit).map { |p| serialize(p) }, has_more: records.length > limit, page: page }
      end
      data = if query.empty? && page <= 10
        CatalogCache.fetch("page:#{page}:limit:#{limit}", ttl: 5, &loader)
      else
        loader.call
      end
      render json: data
    end

    def show
      product = Product.available.find(params[:id])
      render json: serialize(product)
    end

    private
    def serialize(p)
      { id: p.id, sku: p.sku, name: p.name, description: p.description,
        price_cents: p.price_cents, stock: p.stock }
    end
  end
end
