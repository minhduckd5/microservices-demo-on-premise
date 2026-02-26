-- Catalog service seed data

CREATE TABLE IF NOT EXISTS categories (
    id   VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(120) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS products (
    id          VARCHAR(36) PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    slug        VARCHAR(280) NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    price       NUMERIC(10,2) NOT NULL,
    stock       INTEGER NOT NULL DEFAULT 0,
    category_id VARCHAR(36) REFERENCES categories(id) ON DELETE SET NULL,
    image_url   VARCHAR(500),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO categories (id, name, slug) VALUES
  ('cat-001', 'Electronics', 'electronics'),
  ('cat-002', 'Clothing',    'clothing'),
  ('cat-003', 'Books',       'books')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO products (id, name, slug, description, price, stock, category_id, image_url) VALUES
  ('prod-001', 'Wireless Headphones',  'wireless-headphones',  'Premium noise-cancelling wireless headphones', 79.99,  50, 'cat-001', 'https://placehold.co/400x300?text=Headphones'),
  ('prod-002', 'Mechanical Keyboard',  'mechanical-keyboard',  'RGB mechanical keyboard with Cherry MX switches', 129.99, 30, 'cat-001', 'https://placehold.co/400x300?text=Keyboard'),
  ('prod-003', 'USB-C Hub',            'usb-c-hub',            '7-in-1 USB-C hub with 4K HDMI output',        39.99, 100, 'cat-001', 'https://placehold.co/400x300?text=Hub'),
  ('prod-004', 'Smartwatch',           'smartwatch',           'Fitness tracking smartwatch with GPS',        199.99,  20, 'cat-001', 'https://placehold.co/400x300?text=Smartwatch'),
  ('prod-005', 'Running Shoes',        'running-shoes',        'Lightweight running shoes for all terrains',   59.99,  75, 'cat-002', 'https://placehold.co/400x300?text=Shoes'),
  ('prod-006', 'Graphic T-Shirt',      'graphic-t-shirt',      'Cotton graphic t-shirt in multiple colours',   19.99, 200, 'cat-002', 'https://placehold.co/400x300?text=T-Shirt'),
  ('prod-007', 'Denim Jacket',         'denim-jacket',         'Classic denim jacket with button closure',     89.99,  40, 'cat-002', 'https://placehold.co/400x300?text=Jacket'),
  ('prod-008', 'Clean Code',           'clean-code',           'A handbook of agile software craftsmanship',   34.99, 150, 'cat-003', 'https://placehold.co/400x300?text=Book'),
  ('prod-009', 'The Pragmatic Programmer', 'the-pragmatic-programmer', 'From journeyman to master',           44.99, 120, 'cat-003', 'https://placehold.co/400x300?text=Book'),
  ('prod-010', 'Designing Data-Intensive Applications', 'designing-data-intensive-applications', 'The big ideas behind reliable, scalable systems', 54.99, 80, 'cat-003', 'https://placehold.co/400x300?text=Book')
ON CONFLICT (slug) DO NOTHING;
