-- Auth service seed data

CREATE TABLE IF NOT EXISTS users (
    id          VARCHAR(36) PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    hashed_password VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sessions (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       VARCHAR(512) NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL
);

-- bcrypt hash of "admin123"
INSERT INTO users (id, email, hashed_password, created_at) VALUES
  ('00000000-0000-0000-0000-000000000001',
   'admin@demo.com',
   '$2b$12$KIX/lbMkSdGp1j3hQaVpQOZzAHhXhqLBr5.9qzwxdFXXYhGkrjvAm',
   NOW())
ON CONFLICT (email) DO NOTHING;

-- bcrypt hash of "user123"
INSERT INTO users (id, email, hashed_password, created_at) VALUES
  ('00000000-0000-0000-0000-000000000002',
   'user@demo.com',
   '$2b$12$3QmdrPghPzqJqniLbdnb3.N4TdnDTqWEZ1hGfC5oXSqdNVMuPxWNi',
   NOW())
ON CONFLICT (email) DO NOTHING;
