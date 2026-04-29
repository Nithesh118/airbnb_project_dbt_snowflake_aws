# 🏠 Airbnb Data Pipeline — dbt + Snowflake + AWS S3

A full end-to-end data engineering project that ingests raw Airbnb data from **AWS S3** into **Snowflake**, transforms it using **dbt-core** with a medallion architecture (Bronze → Silver → Gold), and implements a **Star Schema** for analytical consumption.

---

## 🏗️ Architecture Overview

```
AWS S3 (Raw CSVs)
       │
       ▼
  Snowflake Stage (snowstage)
       │
       ▼
  Snowflake Tables (bookings, listings, hosts)
       │
       ▼
  dbt-core (local transformations)
       │
  ┌────┴────────────────────────┐
  ▼            ▼                ▼
Bronze       Silver            Gold
(raw ingest) (cleaned/joined)  (Star Schema OBT)
                                     │
                                     ▼
                               Snapshots (SCD Type 2)
```

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| **AWS S3** | Raw data storage (bookings.csv, listings.csv, hosts.csv) |
| **Snowflake** | Cloud data warehouse |
| **dbt-core** | Transformation framework |
| **dbt-snowflake** | dbt adapter for Snowflake |
| **uv** | Python package manager & virtual environment |
| **VS Code** | Development IDE |

---

## 📁 Project Structure

```
airbnb_project_dbt_snowflake_aws/
│
├── dataset/                         # Raw CSV files
│
├── aws_dbt_snowflake_project/       # dbt project root
│   ├── models/
│   │   ├── bronze/                  # Raw ingestion from source
│   │   │   ├── bronze_bookings.sql
│   │   │   ├── bronze_hosts.sql
│   │   │   ├── bronze_listings.sql
│   │   │   └── properties.yml
│   │   │
│   │   ├── silver/                  # Cleaned & enriched models
│   │   │   ├── silver_bookings.sql
│   │   │   ├── silver_hosts.sql
│   │   │   └── silver_listing.sql
│   │   │
│   │   ├── gold/                    # Analytical / Star Schema
│   │   │   ├── fact.sql             # Fact table
│   │   │   ├── obt.sql              # One Big Table
│   │   │   └── ephemeral/           # Intermediate ephemeral models
│   │   │       ├── bookings.sql
│   │   │       ├── hosts.sql
│   │   │       └── listings.sql
│   │   │
│   │   └── sources/
│   │       └── sources.yml          # Source definitions
│   │
│   ├── macros/
│   │   ├── generate_schema_name.sql # Dynamic schema override macro
│   │   ├── tag.sql                  # Price tagging macro (low/medium/high)
│   │   ├── trimmer.sql              # String trimming utility macro
│   │   └── multiply.sql             # Numeric utility macro
│   │
│   ├── snapshots/                   # SCD Type 2 snapshots
│   │   ├── dim_bookings.yml
│   │   ├── dim_hosts.yml
│   │   └── dim_listings.yml
│   │
│   ├── tests/                       # Data quality tests
│   ├── seeds/
│   ├── dbt_project.yml              # Project configuration
│   └── profiles.yml                 # Connection profiles
│
├── main.py
├── pyproject.toml
├── uv.lock
└── .python-version
```

---

## ⚙️ Setup & Configuration

### 1. Prerequisites

- Python 3.10+
- [uv](https://github.com/astral-sh/uv) package manager
- Snowflake account
- AWS S3 bucket with Airbnb CSVs

### 2. Clone & Install

```bash
git clone https://github.com/Nithesh118/airbnb_project_dbt_snowflake_aws.git
cd airbnb_project_dbt_snowflake_aws

# Create virtual environment and install dependencies
uv venv
uv pip install dbt-core dbt-snowflake
```

### 3. Snowflake Setup

Run the DDL and resource scripts in Snowflake Worksheets:

```sql
-- Create file format
CREATE OR REPLACE FILE FORMAT IF NOT EXISTS csv_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Create external stage pointing to S3
CREATE OR REPLACE STAGE snowstage
    FILE_FORMAT = csv_format
    URL = 's3://snowbucketnith/source/';

-- Load data from S3 into Snowflake
COPY INTO bookings
FROM @snowstage
FILES = ('bookings.csv')
CREDENTIALS = (aws_key_id = '<your_key>' aws_secret_key = '<your_secret>');
```

### 4. Configure dbt Profile

Edit `profiles.yml` (located at `~/.dbt/profiles.yml` or project root):

```yaml
aws_dbt_snowflake_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your_account>
      user: <your_user>
      password: <your_password>
      role: ACCOUNTADMIN
      database: airbnb
      warehouse: COMPUTE_WH
      schema: staging
      threads: 4
```

---

## 🧱 Medallion Architecture

### Bronze Layer
Direct ingestion from Snowflake source tables. No transformations — raw data as-is.
- Schema: `bronze`
- Materialization: view

### Silver Layer
Cleaned, deduplicated, and type-cast models. Joins applied where relevant.
- Schema: `silver`
- Materialization: view

### Gold Layer
Business-ready models following Star Schema design.
- Schema: `gold`
- Materialization: **table**
- Includes an OBT (One Big Table) and a Fact table for analytics

### Ephemeral Layer
Intermediate CTEs used within the Gold layer — not materialized in Snowflake.
- Materialization: `ephemeral`

---

## 📸 Snapshots (SCD Type 2)

Snapshots track slowly changing dimensions using the **timestamp strategy**.

```yaml
# Example: dim_listings snapshot
snapshots:
  - name: dim_listings
    relation: ref('listings')
    config:
      schema: gold
      database: airbnb
      unique_key: listing_id
      strategy: timestamp
      updated_at: listing_created_at
      dbt_valid_to_current: "to_date('9999-12-31')"
```

Snapshots for `dim_bookings`, `dim_hosts`, and `dim_listings` are all configured similarly.

---

## 🔧 Custom Macros

| Macro | Description |
|-------|-------------|
| `generate_schema_name` | Overrides dbt's default schema generation to support multi-schema deployments |
| `tag(col)` | Classifies a numeric column into `'low'`, `'medium'`, or `'high'` buckets |
| `trimmer` | Strips whitespace from string columns |
| `multiply` | Utility for numeric column operations |

Example usage of the `tag` macro in a model:

```sql
SELECT
    listing_id,
    price,
    {{ tag('price') }} AS price_category
FROM {{ ref('silver_listing') }}
```

---

## 🗂️ Source Configuration

```yaml
# sources/sources.yml
sources:
  - name: staging
    database: airbnb
    schema: staging
    tables:
      - name: listings
      - name: bookings
      - name: hosts
```

---

## 🚀 Running dbt

```bash
cd aws_dbt_snowflake_project

# Install dbt packages
dbt deps

# Run all models
dbt run

# Run specific layer
dbt run --select bronze
dbt run --select silver
dbt run --select gold

# Run snapshots
dbt snapshot

# Test data quality
dbt test

# Generate and serve docs
dbt docs generate
dbt docs serve
```

---

## 📊 dbt Project Configuration

```yaml
# dbt_project.yml (models section)
models:
  aws_dbt_snowflake_project:
    bronze:
      +schema: bronze
    silver:
      +schema: silver
    gold:
      +materialized: table
      +schema: gold
      ephemeral:
        +materialized: ephemeral
```

---

## 🌟 Key Concepts Demonstrated

- **AWS S3 → Snowflake ingestion** via external stage and `COPY INTO`
- **dbt-snowflake adapter** configuration and usage
- **Medallion architecture** (Bronze / Silver / Gold)
- **Ephemeral models** as reusable CTEs
- **SCD Type 2 snapshots** with timestamp strategy
- **Custom Jinja macros** for dynamic schema naming and column tagging
- **Star schema** design for analytical workloads
- **uv** for fast, reproducible Python environment management

---

> ⭐ If you found this project helpful, consider giving it a star!
