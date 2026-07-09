-- Seed data for the EDI order generator example.
-- One purchase order (PO20260615) with two line items.

CREATE TABLE orders (
    order_id    TEXT PRIMARY KEY,
    buyer_id    TEXT NOT NULL,
    supplier_id TEXT NOT NULL,
    order_date  TEXT NOT NULL
);

CREATE TABLE order_items (
    order_id  TEXT NOT NULL REFERENCES orders (order_id),
    line_no   INT  NOT NULL,
    item_code TEXT NOT NULL,
    quantity  INT  NOT NULL,
    PRIMARY KEY (order_id, line_no)
);

INSERT INTO orders VALUES ('PO20260615', 'BUYER123', 'ACME', '20260615');

INSERT INTO order_items VALUES
    ('PO20260615', 1, 'ITEM-A', 100),
    ('PO20260615', 2, 'ITEM-B', 50);
