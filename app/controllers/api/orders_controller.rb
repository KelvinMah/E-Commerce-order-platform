module Api
  class OrdersController < ApplicationController
    def create
      key = request.headers["Idempotency-Key"]
      items = params.require(:items).map { |i| i.permit(:product_id, :quantity).to_h.symbolize_keys }
      order = CheckoutService.new(email: params[:email], idempotency_key: key, items: items).call
      render json: OrderSerializer.call(order), status: :created
    rescue CheckoutService::InvalidCart, ActionController::ParameterMissing => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue CheckoutService::OutOfStock => e
      render json: { error: e.message }, status: :conflict
    rescue CheckoutService::KeyConflict => e
      render json: { error: e.message }, status: :conflict
    end

    def show
      order = Order.includes(order_items: :product).find(params[:id])
      render json: OrderSerializer.call(order)
    end

    def cancel
      order = Order.find(params[:id])
      Order.transaction do
        order.lock!
        if order.status == "confirmed"
          order.order_items.order(:product_id).each do |item|
            product = Product.lock.find(item.product_id)
            product.update!(stock: product.stock + item.quantity)
          end
          order.update!(status: "cancelled", cancelled_at: Time.current)
        end
      end
      render json: OrderSerializer.call(order.reload)
    end
  end
end
