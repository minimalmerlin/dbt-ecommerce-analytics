# E-Commerce Analytics dbt Portfolio Projekt

![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![dbt](https://img.shields.io/badge/dbt-1.5+-orange.svg)
![DuckDB](https://img.shields.io/badge/DuckDB-0.9+-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![SQL](https://img.shields.io/badge/SQL-advanced-blue.svg)

Ein vollständiges, lokal ausführbares dbt-Projekt, das fortgeschrittene SQL-Kompetenzen und moderne Data Engineering Best Practices demonstriert.

## 🎯 Projektziel

Dieses Projekt simuliert einen typischen "Modern Data Stack" Workflow für E-Commerce/SaaS Analytics:
**Raw Data → Staging → Intermediate → Marts**

Es zeigt praxisnahe Datenverarbeitung mit:
- Datenbereinigung und -standardisierung
- Komplexen SQL-Transformationen (CTEs, Window Functions, Aggregationen)
- Data Quality Testing
- Dimensional Modeling (Facts & Dimensions)

## 🏗️ Architektur

```
├── Raw Layer (Seeds)
│   ├── raw_customers.csv
│   ├── raw_orders.csv
│   └── raw_payments.csv
│
├── Staging Layer (Views)
│   ├── stg_customers      → Bereinigung, Standardisierung
│   ├── stg_orders         → Datumsformate, Status-Normalisierung
│   └── stg_payments       → Methoden-Standardisierung
│
├── Intermediate Layer (Views)
│   └── int_customer_cohorts → Window Functions, Cohort Analysis
│
└── Marts Layer (Tables)
    ├── fct_orders         → Fakten-Tabelle für Analytics
    └── dim_customers      → Kunden-Dimensionen mit Metriken
```

## 📊 Demonstrierte SQL-Techniken

### Staging Layer
- `CASE WHEN` für Datenbereinigung
- String-Manipulation (`TRIM`, `SUBSTR`)
- Datumsformat-Standardisierung
- NULL-Handling und Default-Werte

### Intermediate Layer
- **Window Functions:**
  - `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`
  - `PERCENT_RANK() OVER (...)`
  - `AVG() OVER (PARTITION BY ...)`
  - `FIRST_VALUE() OVER (...)`
- **Zeitfunktionen:**
  - `DATE_TRUNC('month', ...)`
  - `DATE_DIFF('day', ...)`
  - `EXTRACT(year FROM ...)`
- CTEs für strukturierte Logik

### Marts Layer
- Komplexe Aggregationen (`SUM`, `AVG`, `COUNT`, `MODE`)
- Mehrstufige JOINs
- Berechnete Metriken (LTV, AOV, Recency)
- Customer Segmentierung (RFM-inspiriert)
- Business Logic (Revenue Recognition)

## 🚀 Setup & Installation

### Voraussetzungen
```bash
# Python 3.8+
python --version

# pip installieren
pip install --upgrade pip
```

### 1. dbt und DuckDB installieren
```bash
pip install dbt-duckdb
```

### 2. Testdaten generieren
```bash
# Im Projektordner
python generate_data.py
```

Dies erstellt 3 CSV-Dateien im `seeds/` Ordner mit absichtlichen Datenfehlern:
- **raw_customers.csv** (500 Kunden)
- **raw_orders.csv** (~1500 Bestellungen)
- **raw_payments.csv** (~1400 Payments)

**Eingebaute Datenfehler:**
- NULL-Werte in verschiedenen Feldern
- Inkonsistente Datumsformate (YYYY-MM-DD vs DD.MM.YYYY)
- Negative Beträge
- Fehlende Payments für manche Orders
- Payment/Order Betrag-Diskrepanzen

### 3. dbt Profil konfigurieren

Das Projekt nutzt `profiles.yml` im Projektordner (DuckDB lokal):

```yaml
ecommerce_analytics:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: 'data/ecommerce_analytics.duckdb'
```

### 4. dbt ausführen

```bash
# 1. Seeds laden (Raw Data)
dbt seed --profiles-dir .

# 2. Alle Modelle bauen
dbt run --profiles-dir .

# 3. Tests ausführen
dbt test --profiles-dir .

# 4. Dokumentation generieren
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

## 📈 Business-Fragen, die mit diesem Projekt beantwortet werden

### 1. Wer sind unsere Top-Kunden?
```sql
SELECT
    customer_id,
    full_name,
    total_lifetime_value,
    total_orders,
    customer_segment,
    value_segment
FROM marts.dim_customers
ORDER BY total_lifetime_value DESC
LIMIT 10;
```

### 2. Wie entwickeln sich unsere Kohorten?
```sql
SELECT
    cohort_month,
    cohort_size,
    AVG(total_order_value) as avg_cohort_value,
    COUNT(CASE WHEN customer_segment != 'Never Purchased' THEN 1 END) as active_customers
FROM intermediate.int_customer_cohorts
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;
```

### 3. Welche Kunden sind gefährdet (At Risk)?
```sql
SELECT
    customer_id,
    full_name,
    total_lifetime_value,
    days_since_last_order,
    recency_segment
FROM marts.dim_customers
WHERE recency_segment IN ('At Risk (90-180 days)', 'Churned (180+ days)')
    AND total_lifetime_value > 500
ORDER BY total_lifetime_value DESC;
```

### 4. Revenue-Analyse nach Monat
```sql
SELECT
    order_date_month,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(*) as total_orders,
    SUM(recognized_revenue) as total_revenue,
    AVG(recognized_revenue) as avg_order_value
FROM marts.fct_orders
WHERE has_successful_payment = true
GROUP BY order_date_month
ORDER BY order_date_month;
```

### 5. Payment-Method-Performance
```sql
SELECT
    payment_method,
    COUNT(*) as total_orders,
    SUM(recognized_revenue) as total_revenue,
    AVG(recognized_revenue) as avg_revenue,
    COUNT(CASE WHEN has_payment_discrepancy THEN 1 END) as discrepancies
FROM marts.fct_orders
WHERE payment_method IS NOT NULL
GROUP BY payment_method
ORDER BY total_revenue DESC;
```

### 6. Customer Lifetime Journey
```sql
SELECT
    c.customer_id,
    c.full_name,
    c.signup_date,
    c.first_order_date,
    c.days_to_first_order,
    c.total_orders,
    c.total_lifetime_value,
    c.avg_orders_per_month,
    c.customer_segment
FROM marts.dim_customers c
WHERE c.has_purchased = true
ORDER BY c.total_lifetime_value DESC
LIMIT 20;
```

## 🧪 Testing

Das Projekt enthält umfangreiche dbt-Tests:

- **Unique/Not Null Tests:** Primärschlüssel-Validierung
- **Relationships Tests:** Foreign Key Integrität
- **Accepted Values Tests:** Status- und Kategorie-Validierung

```bash
# Alle Tests ausführen
dbt test --profiles-dir .

# Nur Staging-Tests
dbt test --select staging --profiles-dir .

# Nur ein Modell testen
dbt test --select dim_customers --profiles-dir .
```

## 📁 Projektstruktur

```
dbt_portfolio_project/
├── README.md                          # Diese Datei
├── generate_data.py                   # Python-Script für Datengenerierung
├── dbt_project.yml                    # dbt Projekt-Konfiguration
├── profiles.yml                       # DuckDB-Verbindung
│
├── seeds/                             # Raw Data (CSV)
│   ├── raw_customers.csv
│   ├── raw_orders.csv
│   └── raw_payments.csv
│
├── models/
│   ├── staging/                       # Datenbereinigung
│   │   ├── schema.yml
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   └── stg_payments.sql
│   │
│   ├── intermediate/                  # Erweiterte Transformationen
│   │   ├── schema.yml
│   │   └── int_customer_cohorts.sql
│   │
│   └── marts/                         # Analytics-ready Tables
│       ├── schema.yml
│       ├── fct_orders.sql
│       └── dim_customers.sql
│
└── data/                              # DuckDB-Datei (generiert)
    └── ecommerce_analytics.duckdb
```

## 🎓 Lernziele & Portfolio-Relevanz

Dieses Projekt demonstriert:

1. **Modern Data Stack Kenntnisse:** dbt, SQL, dimensional modeling
2. **SQL-Expertise:** Window Functions, CTEs, komplexe Aggregationen
3. **Data Quality:** Testing, Validierung, Fehlerbehandlung
4. **Business Understanding:** E-Commerce Metriken (LTV, AOV, RFM)
5. **Best Practices:** Modulare Code-Struktur, Dokumentation, Reproduzierbarkeit

## 🔍 Nächste Schritte für Erweiterungen

- **Visualisierung:** BI-Tool anbinden (Metabase, Tableau, Power BI)
- **Macros:** Wiederverwendbare dbt-Macros schreiben
- **Incremental Models:** Für große Datenmengen optimieren
- **Snapshots:** Historische Daten tracken (SCD Type 2)
- **Erweiterte Analytics:** Churn Prediction, Customer Clustering

## 📝 Lizenz

Dieses Projekt ist für Portfolio- und Lernzwecke erstellt.

---

**Erstellt mit:** dbt + DuckDB + Python
**Autor:** Merlin Mechler
**Datum:** 2025
