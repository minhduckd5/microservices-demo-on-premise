-- Orders service seed data

CREATE TABLE IF NOT EXISTS orders (
    id         VARCHAR(36) PRIMARY KEY,
    user_id    VARCHAR(255) NOT NULL,
    status     VARCHAR(50) NOT NULL DEFAULT 'pending',
    total      NUMERIC(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
    id         VARCHAR(36) PRIMARY KEY,
    order_id   VARCHAR(36) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(255) NOT NULL,
    quantity   INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(10,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
