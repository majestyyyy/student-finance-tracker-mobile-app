-- Student Finance Tracker — Phase 1 Schema (3NF)
-- PostgreSQL 14+

BEGIN;

-- ---------------------------------------------------------------------------
-- users: links local entities to Microsoft Entra External ID (Azure AD B2C)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id              SERIAL          PRIMARY KEY,
    azure_user_id   VARCHAR(255)    NOT NULL,
    email           VARCHAR(320)    NOT NULL,
    display_name    VARCHAR(200),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_users_azure_user_id UNIQUE (azure_user_id),
    CONSTRAINT chk_users_email_format CHECK (
        email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    )
);

CREATE INDEX IF NOT EXISTS idx_users_azure_user_id ON users (azure_user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- ---------------------------------------------------------------------------
-- account_types: static normalization lookup
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS account_types (
    id              SERIAL          PRIMARY KEY,
    code            VARCHAR(50)     NOT NULL,
    display_name    VARCHAR(100)    NOT NULL,
    description     TEXT,
    sort_order      SMALLINT        NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_account_types_code UNIQUE (code),
    CONSTRAINT chk_account_types_code_not_empty CHECK (LENGTH(TRIM(code)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_account_types_code ON account_types (code);
CREATE INDEX IF NOT EXISTS idx_account_types_active_sort
    ON account_types (is_active, sort_order);

-- ---------------------------------------------------------------------------
-- accounts: user wallets / financial accounts with typed balances
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
    id                  SERIAL              PRIMARY KEY,
    user_id             INTEGER             NOT NULL,
    account_type_id     INTEGER             NOT NULL,
    name                VARCHAR(200)        NOT NULL,
    balance             DECIMAL(15, 2)      NOT NULL DEFAULT 0.00,
    currency_code       CHAR(3)             NOT NULL DEFAULT 'USD',
    is_active           BOOLEAN             NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_accounts_user
        FOREIGN KEY (user_id)
        REFERENCES users (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_accounts_account_type
        FOREIGN KEY (account_type_id)
        REFERENCES account_types (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_accounts_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
    CONSTRAINT chk_accounts_balance_range CHECK (
        balance >= -999999999999.99 AND balance <= 999999999999.99
    ),
    CONSTRAINT chk_accounts_currency_code CHECK (
        currency_code ~ '^[A-Z]{3}$'
    )
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts (user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_account_type_id ON accounts (account_type_id);
CREATE INDEX IF NOT EXISTS idx_accounts_user_active
    ON accounts (user_id, is_active);

-- ---------------------------------------------------------------------------
-- updated_at trigger helper
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON users;
CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at_timestamp();

DROP TRIGGER IF EXISTS trg_accounts_set_updated_at ON accounts;
CREATE TRIGGER trg_accounts_set_updated_at
    BEFORE UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at_timestamp();

COMMIT;
