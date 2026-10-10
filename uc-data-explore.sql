-- ============================================================
--  UNITY CATALOG DATA EXPLORATION LAB
--  Run each module statement-by-statement (cursor on statement, Run)
--  or run the whole thing with Run All.
-- Check in
-- ============================================================

-- ==========================================================
-- MODULE 1: CATALOGS  — The top level of the UC hierarchy
-- ==========================================================

-- 1a. List every catalog you can see in your workspace.
--     You should see: workspace, samples, system
SHOW CATALOGS;

-- 1b. Inspect catalog-level metadata via the information_schema.
--     Every catalog has a built-in `information_schema` with views
--     that describe the objects inside it.
SELECT catalog_name, catalog_owner
FROM workspace.information_schema.catalogs;

-- 1c. The `samples` catalog contains Databricks-provided demo datasets.
SELECT catalog_name, catalog_owner
FROM samples.information_schema.catalogs;
SELECT catalog_name, catalog_owner,cat.*
FROM samples.information_schema.catalogs cat;

-- 1d. Switch the default catalog for this session.
--     After this, unqualified table references (e.g. `tpch.nation`)
--     resolve within `samples`.
USE CATALOG samples;


-- ==========================================================
-- MODULE 2: SCHEMAS  — Organizing data within a catalog
-- ==========================================================

-- 2a. List all schemas in the `samples` catalog.
--     You'll see tpch, nyctaxi, tpcds_sf1, accuweather, etc.
SHOW SCHEMAS IN samples;

-- 2b. Same thing via information_schema — more columns available.
SELECT schema_name, schema_owner
FROM samples.information_schema.schemata
ORDER BY schema_name;

-- 2c. List schemas in your personal `workspace` catalog.
--     You'll see: auto, default, information_schema
SHOW SCHEMAS IN workspace;


-- ==========================================================
-- MODULE 3: TABLES  — Discovering tables inside a schema
-- ==========================================================

-- 3a. Show all tables in the `tpch` schema within `samples`.
--     TPCH is a classic benchmark dataset with 8 tables.
SHOW TABLES IN samples.tpch;

-- 3b. Same result via information_schema, but with table_type.
--     Notice all tables are 'MANAGED' (UC owns the storage).
SELECT table_name, table_type
FROM samples.information_schema.tables
WHERE table_schema = 'tpch'
ORDER BY table_name;

-- 3c. Also explore the NYC taxi trips dataset.
SHOW TABLES IN samples.nyctaxi;

-- 3d. DESCRIBE a table — see columns, data types, and comments.
DESCRIBE samples.tpch.nation;

-- 3e. DESCRIBE EXTENDED — adds table-level properties (location,
--     type, creator, partition columns, etc.).
DESCRIBE EXTENDED samples.tpch.orders;

-- 3f. DESCRIBE the NYC taxi trips table.
DESCRIBE samples.nyctaxi.trips;


-- ==========================================================
-- MODULE 4: COLUMNS  — Inspecting column-level metadata
-- ==========================================================

-- 4a. Get all columns of the `orders` table via information_schema.
--     This is useful for programmatic exploration.
SELECT column_name, data_type, is_nullable, comment
FROM samples.information_schema.columns
WHERE table_schema = 'tpch' AND table_name = 'orders'
ORDER BY ordinal_position;

-- 4b. Count how many columns each TPCH table has.
SELECT table_name, COUNT(*) AS column_count
FROM samples.information_schema.columns
WHERE table_schema = 'tpch'
GROUP BY table_name
ORDER BY column_count DESC;


-- ==========================================================
-- MODULE 5: DATA EXPLORATION  — Querying governed data
-- ==========================================================

-- 5a. Preview the `nation` lookup table (small, 25 rows).
SELECT * FROM samples.tpch.nation ORDER BY n_nationkey LIMIT 10;

-- 5b. Preview the `region` lookup table (only 5 rows).
SELECT * FROM samples.tpch.region;

-- 5c. Count rows in the orders table.
SELECT COUNT(*) AS total_orders FROM samples.tpch.orders;

-- 5d. Orders by order status — basic aggregation.
SELECT o_orderstatus, COUNT(*) AS order_count
FROM samples.tpch.orders
GROUP BY o_orderstatus
ORDER BY order_count DESC;

-- 5e. Join nation with region for a readable dimension query.
SELECT n.n_name AS nation, r.r_name AS region
FROM samples.tpch.nation n
JOIN samples.tpch.region r ON n.n_regionkey = r.r_regionkey
ORDER BY r.r_name, n.n_name
LIMIT 20;

-- 5f. Top 5 customers by total order amount.
SELECT c.c_name, c.c_mktsegment, COUNT(o.o_orderkey) AS num_orders
FROM samples.tpch.customer c
JOIN samples.tpch.orders o ON c.c_custkey = o.o_custkey
GROUP BY c.c_name, c.c_mktsegment
ORDER BY num_orders DESC
LIMIT 5;


-- ==========================================================
-- MODULE 6: CREATE YOUR OWN CATALOG/SCHEMA/TABLE
-- ==========================================================

-- 6a. Create a new catalog called `lakehouse`.
--     (Already in your query — safe to re-run with IF NOT EXISTS)
CREATE CATALOG IF NOT EXISTS lakehouse
  COMMENT 'Personal lab catalog for UC exploration';

-- 6b. Create a schema inside the new catalog.
CREATE SCHEMA IF NOT EXISTS lakehouse.demo
  COMMENT 'Demo schema for hands-on UC lab';

-- 6c. Create a managed table in your new schema.
--     UC manages both the metadata and the physical storage.
CREATE TABLE IF NOT EXISTS lakehouse.demo.sales_regions (
  region_id   INT          COMMENT 'Unique region identifier',
  region_name STRING       COMMENT 'Human-readable region name',
  country     STRING       COMMENT 'Country code (ISO 3166)',
  created_at  TIMESTAMP    COMMENT 'Row creation timestamp'
)
COMMENT 'Sales region lookup table';

-- 6d. Insert a few rows.
INSERT INTO lakehouse.demo.sales_regions
VALUES
  (1, 'North America', 'USA', CURRENT_TIMESTAMP()),
  (2, 'Western Europe', 'DEU', CURRENT_TIMESTAMP()),
  (3, 'Asia Pacific',   'JPN', CURRENT_TIMESTAMP()),
  (4, 'Latin America',   'BRA', CURRENT_TIMESTAMP());

-- 6e. Verify the data you just loaded.
SELECT * FROM lakehouse.demo.sales_regions ORDER BY region_id;


-- ==========================================================
-- MODULE 7: COMMENTS & TAGS  — Making data discoverable
-- ==========================================================

-- 7a. Add a column comment after creation.
COMMENT ON COLUMN lakehouse.demo.sales_regions.country IS 'ISO 3166-1 alpha-3 country code';

-- 7b. Add a table comment (updates the one from CREATE TABLE).
COMMENT ON TABLE lakehouse.demo.sales_regions IS 'Lookup table mapping sales regions to countries';

-- 7c. Verify comments appear in DESCRIBE.
DESCRIBE EXTENDED lakehouse.demo.sales_regions;

-- 7d. Create and apply a governance tag.
--     Tags help classify data for compliance and discovery.
CREATE TAG IF NOT EXISTS pii IN lakehouse;
ALTER TABLE lakehouse.demo.sales_regions
  SET TAGS pii = 'false';

-- 7e. View tags applied to the table.
SELECT tag_name, tag_value
FROM lakehouse.information_schema.table_tags
WHERE table_schema = 'demo' AND table_name = 'sales_regions';


-- ==========================================================
-- MODULE 8: PERMISSIONS  — Who can access what
-- ==========================================================

-- 8a. Show all grants in your catalog.
--     This reveals who has which privileges on which objects.
SHOW GRANTS IN lakehouse;

-- 8b. Show grants on a specific table.
SHOW GRANTS ON TABLE lakehouse.demo.sales_regions;

-- 8c. Grant read access to all users on the demo schema.
--     (Modify the principal to match a real user or group.)
-- GRANT USE SCHEMA ON SCHEMA lakehouse.demo TO `account users`;
-- GRANT SELECT  ON TABLE  lakehouse.demo.sales_regions TO `account users`;

-- 8d. Check your own current privileges on the catalog.
SELECT catalog_name, privilege_type
FROM lakehouse.information_schema.catalog_privileges
ORDER BY privilege_type;


-- ==========================================================
-- MODULE 9: INFORMATION_SCHEMA DEEP DIVE
--         Programmatic metadata queries
-- ==========================================================

-- 9a. Count tables per schema in the `samples` catalog.
SELECT table_schema, COUNT(*) AS table_count
FROM samples.information_schema.tables
GROUP BY table_schema
ORDER BY table_count DESC;

-- 9b. Find all columns named like 'key' across the TPCH schema.
SELECT table_name, column_name, data_type
FROM samples.information_schema.columns
WHERE table_schema = 'tpch'
  AND column_name LIKE '%key%'
ORDER BY table_name, column_name;

-- 9c. List all views in the workspace catalog's information_schema.
--     These are the metadata views UC provides for every catalog.
SELECT table_name
FROM workspace.information_schema.views
WHERE table_schema = 'information_schema'
ORDER BY table_name;


-- ==========================================================
-- MODULE 10: SYSTEM CATALOG  — Account-level governance data
-- ==========================================================

-- 10a. The `system` catalog has built-in tables for audit, billing,
--      query history, and more. List its schemas.
SHOW SCHEMAS IN system;

-- 10b. Query the audit log for recent Unity Catalog events.
--      Filter by action_type to see UC-specific operations.
SELECT event_time, user_identity, action_name, request_params
FROM system.access.audit
WHERE action_name LIKE '%CATALOG%'
ORDER BY event_time DESC
LIMIT 20;

-- 10c. See your recent query history (lightweight view).
SELECT start_time, statement_text, total_duration_ms
FROM system.query.history
ORDER BY start_time DESC
LIMIT 10;


-- ==========================================================
-- LAB COMPLETE — Key takeaways:
--   1. Catalogs > Schemas > Tables (3-level namespace)
--   2. information_schema views give programmatic metadata
--   3. DESCRIBE EXTENDED reveals table-level properties
--   4. Comments and tags make data discoverable & governable
--   5. SHOW GRANTS reveals who has access
--   6. The system catalog tracks audit logs & query history
-- ==========================================================
