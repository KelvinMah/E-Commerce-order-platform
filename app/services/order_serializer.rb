class OrderSerializer
  def self.call(order)
    { id: order.id, email: order.email, status: order.status, total_cents: order.total_cents,
      created_at: order.created_at.iso8601,
      items: order.order_items.map { |item| { product_id: item.product_id, name: item.product.name,
        quantity: item.quantity, unit_price_cents: item.unit_price_cents } } }
  end
end
