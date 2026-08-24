```mermaid
erDiagram
    WAREHOUSES ||--o{ ZONES : contains
    ZONES ||--o{ INVENTORY : stores
    PRODUCTS ||--o{ INVENTORY : has
    PRODUCTS }o--|| CATEGORIES : belongs_to
    SUPPLIERS ||--o{ REPLENISHMENT_ORDERS : receives
    REPLENISHMENT_ORDERS ||--|{ REPLENISHMENT_ITEMS : contains
    PRODUCTS ||--o{ REPLENISHMENT_ITEMS : requested_in
    CUSTOMERS ||--o{ ORDERS : places
    ORDERS ||--|{ ORDER_ITEMS : contains
    PRODUCTS ||--o{ ORDER_ITEMS : sold_in
    WAREHOUSES ||--o{ INVENTORY_AUDITS : undergoes
    INVENTORY_AUDITS ||--|{ AUDIT_ITEMS : records
    PRODUCTS ||--o{ MOVEMENTS : tracked_in
    WAREHOUSES ||--o{ MOVEMENTS : happens_in

    WAREHOUSES {
        int id PK
        string name
        string location
    }
    ZONES {
        int id PK
        int warehouse_id FK
        string name
        string type
    }
    CATEGORIES {
        int id PK
        string name
    }
    PRODUCTS {
        int id PK
        string name
        int category_id FK
        numeric min_stock
        numeric reorder_point
    }
    SUPPLIERS {
        int id PK
        string name
        int lead_time_days
    }
    CUSTOMERS {
        int id PK
        string name
        string segment
    }
    INVENTORY {
        int product_id FK
        int zone_id FK
        numeric quantity
        numeric reserved_qty
    }
    ORDERS {
        int id PK
        int customer_id FK
        date order_date
        string status
    }
    ORDER_ITEMS {
        int order_id FK
        int product_id FK
        numeric qty
        numeric price
    }
    REPLENISHMENT_ORDERS {
        int id PK
        int supplier_id FK
        date order_date
        string status
    }
    REPLENISHMENT_ITEMS {
        int order_id FK
        int product_id FK
        numeric qty
    }
    INVENTORY_AUDITS {
        int id PK
        int warehouse_id FK
        date audit_date
        string status
    }
    AUDIT_ITEMS {
        int audit_id FK
        int product_id FK
        numeric system_qty
        numeric actual_qty
    }
    MOVEMENTS {
        int id PK
        int product_id FK
        int warehouse_id FK
        date movement_date
        string type
        numeric qty
    }
