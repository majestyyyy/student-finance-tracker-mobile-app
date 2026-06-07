-- Seed data for account_types lookup table
-- Run after schema.sql

BEGIN;

INSERT INTO account_types (code, display_name, description, sort_order)
VALUES
    ('cash',              'Cash',              'Physical cash on hand',                    1),
    ('traditional_bank',  'Traditional Bank',  'Checking or savings at a brick-and-mortar bank', 2),
    ('digital_bank',      'Digital Bank',      'Neobank or digital-only banking account',  3),
    ('credit_card',       'Credit Card',       'Revolving credit line',                    4),
    ('bnpl',              'Buy Now Pay Later', 'Installment payment services',             5),
    ('savings',           'Savings',           'Dedicated savings or emergency fund',      6)
ON CONFLICT (code) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    sort_order   = EXCLUDED.sort_order,
    is_active    = TRUE;

COMMIT;
