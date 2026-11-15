from pathlib import Path
import sqlite3
import pandas as pd

base_dir = Path(__file__).resolve().parent
pasta_data = base_dir / "data"
pasta_ddl = base_dir / "ddl"
pasta_etl = base_dir / "etl"
db_path = base_dir / "olist_dw.sqlite"

tabelas_csv = {
    "olist_orders_dataset.csv": "stg_orders",
    "olist_order_items_dataset.csv": "stg_order_items",
    "olist_order_payments_dataset.csv": "stg_order_payments",
    "olist_order_reviews_dataset.csv": "stg_order_reviews",
    "olist_customers_dataset.csv": "stg_customers",
    "olist_sellers_dataset.csv": "stg_sellers",
    "olist_products_dataset.csv": "stg_products",
    "olist_geolocation_dataset.csv": "stg_geolocation",
    "product_category_name_translation.csv": "stg_category_translation",
}

colunas_cep = {
    "customer_zip_code_prefix": str,
    "seller_zip_code_prefix": str,
    "geolocation_zip_code_prefix": str,
}

def rodar_etl():
    conn = sqlite3.connect(db_path)
    try:
        for arquivo_ddl in ["01_create_staging.sql", "02_create_dw.sql"]:
            sql = (pasta_ddl / arquivo_ddl).read_text(encoding="utf-8")
            conn.executescript(sql)

        for arquivo, tabela in tabelas_csv.items():
            df = pd.read_csv(pasta_data / arquivo, dtype=colunas_cep)
            df.to_sql(tabela, conn, if_exists="append", index=False)

        etl_sql = (pasta_etl / "etl_dw.sql").read_text(encoding="utf-8")
        conn.executescript(etl_sql)

        fk_erros = conn.execute("PRAGMA foreign_key_check").fetchall()
        if fk_erros:
            print(f"Erro!")
        else:
            print("Sucesso!")
    finally:
        conn.close()

if __name__ == "__main__":
    rodar_etl()