-- Azure PostgreSQL live schema (student-money-db)
-- Matches Entra External ID users.id (VARCHAR sub) and wallet hierarchy columns.

BEGIN;

-- users: Entra sub claim is the primary key
CREATE TABLE IF NOT EXISTS users (
    id              VARCHAR(255)    PRIMARY KEY,
    email           VARCHAR(320)    NOT NULL,
    display_name    VARCHAR(200),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- accounts: denormalized account_type / type_label (no account_types lookup table)
CREATE TABLE IF NOT EXISTS accounts (
    id              SERIAL          PRIMARY KEY,
    user_id         VARCHAR(255)    NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    account_type    VARCHAR(50)     NOT NULL DEFAULT 'cash',
    type_label      VARCHAR(100)    NOT NULL DEFAULT 'Cash',
    name            VARCHAR(200)    NOT NULL,
    type_group      VARCHAR(20)     NOT NULL DEFAULT 'asset',
    balance         DECIMAL(15, 2)  NOT NULL DEFAULT 0.00,
    credit_limit    DECIMAL(15, 2),
    remaining_debt  DECIMAL(15, 2),
    due_date_flag   TEXT,
    currency_code   CHAR(3)         NOT NULL DEFAULT 'PHP',
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_accounts_type_group
        CHECK (type_group IN ('asset', 'credit', 'debt'))
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts (user_id);

CREATE TABLE IF NOT EXISTS categories (
    id              SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    icon_emoji      VARCHAR(10),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transactions (
    id              SERIAL          PRIMARY KEY,
    user_id         VARCHAR(255)    NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    account_id      INTEGER         NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    category_id     INTEGER         REFERENCES categories (id) ON DELETE SET NULL,
    title           VARCHAR(200)    NOT NULL,
    amount          DECIMAL(15, 2)  NOT NULL,
    is_expense      BOOLEAN         NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions (account_id);

COMMIT;
