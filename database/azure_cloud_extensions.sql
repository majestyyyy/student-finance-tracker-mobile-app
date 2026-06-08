-- Migrate an existing Azure DB from Phase-1 schema.sql to the live API schema.
-- Safe to run multiple times (IF NOT EXISTS / conditional alters).

BEGIN;

-- ---------------------------------------------------------------------------
-- users: Entra sub VARCHAR primary key (skip if already migrated)
-- ---------------------------------------------------------------------------
-- If your users table still uses SERIAL + azure_user_id, migrate manually first.

-- ---------------------------------------------------------------------------
-- accounts: wallet hierarchy + denormalized type columns
-- ---------------------------------------------------------------------------
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS account_type VARCHAR(50),
  ADD COLUMN IF NOT EXISTS type_label VARCHAR(100),
  ADD COLUMN IF NOT EXISTS type_group VARCHAR(20) NOT NULL DEFAULT 'asset',
  ADD COLUMN IF NOT EXISTS credit_limit DECIMAL(15, 2),
  ADD COLUMN IF NOT EXISTS remaining_debt DECIMAL(15, 2),
  ADD COLUMN IF NOT EXISTS due_date_flag TEXT;

UPDATE accounts
SET account_type = COALESCE(account_type, 'cash')
WHERE account_type IS NULL;

UPDATE accounts
SET type_label = COALESCE(type_label, name)
WHERE type_label IS NULL;

-- Backfill account_type/type_label from account_types when the legacy FK exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'accounts' AND column_name = 'account_type_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_name = 'account_types'
  ) THEN
    UPDATE accounts a
    SET
      account_type = COALESCE(a.account_type, at.code),
      type_label = COALESCE(a.type_label, at.display_name)
    FROM account_types at
    WHERE a.account_type_id = at.id;
  END IF;
END $$;

ALTER TABLE accounts
  DROP CONSTRAINT IF EXISTS chk_accounts_type_group;

ALTER TABLE accounts
  ADD CONSTRAINT chk_accounts_type_group
  CHECK (type_group IN ('asset', 'credit', 'debt'));

-- Align user_id with users.id VARCHAR (Entra sub).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'accounts'
      AND column_name = 'user_id'
      AND data_type <> 'character varying'
  ) THEN
    ALTER TABLE accounts DROP CONSTRAINT IF EXISTS fk_accounts_user;
    ALTER TABLE accounts
      ALTER COLUMN user_id TYPE VARCHAR(255)
      USING user_id::text;
    ALTER TABLE accounts
      ADD CONSTRAINT fk_accounts_user
      FOREIGN KEY (user_id) REFERENCES users (id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- categories + transactions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
  id              SERIAL PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  icon_emoji      VARCHAR(10),
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transactions (
  id              SERIAL PRIMARY KEY,
  user_id         VARCHAR(255) NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  account_id      INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  category_id     INTEGER REFERENCES categories (id) ON DELETE SET NULL,
  title           VARCHAR(200) NOT NULL,
  amount          DECIMAL(15, 2) NOT NULL,
  is_expense      BOOLEAN NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions (account_id);

COMMIT;
