import argparse
import sqlite3
import unicodedata
from pathlib import Path
import pandas as pd

RAIZ = Path(__file__).resolve().parent
DB_PATH = RAIZ / "olist_dw.sqlite"
DATA_DIR = RAIZ / "data"

ARQUIVOS_STAGING = {
    "stg_customers": "olist_customers_dataset.csv",
    "stg_geolocation": "olist_geolocation_dataset.csv",
    "stg_order_items": "olist_order_items_dataset.csv",
    "stg_order_payments": "olist_order_payments_dataset.csv",
    "stg_order_reviews": "olist_order_reviews_dataset.csv",
    "stg_orders": "olist_orders_dataset.csv",
    "stg_products": "olist_products_dataset.csv",
    "stg_sellers": "olist_sellers_dataset.csv",
    "stg_category_translation": "product_category_name_translation.csv",
}

COLUNAS_TEXTO = {
    "customer_zip_code_prefix": str,
    "seller_zip_code_prefix": str,
    "geolocation_zip_code_prefix": str,
}


def normalizar_cidade(texto: str) -> str:
    if texto is None:
        return "DESCONHECIDO"
    limpo = " ".join(str(texto).strip().upper().split())
    sem_acento = "".join(
        c for c in unicodedata.normalize("NFD", limpo)
        if unicodedata.category(c) != "Mn"
    )
    return sem_acento if sem_acento else "DESCONHECIDO"


def carregar_staging(conn: sqlite3.Connection) -> None:
    conn.executescript((RAIZ / "ddl" / "01_create_staging.sql").read_text(encoding="utf-8"))
    for tabela, arquivo in ARQUIVOS_STAGING.items():
        caminho_csv = DATA_DIR / arquivo
        if not caminho_csv.exists():
            raise FileNotFoundError(f"Arquivo nao encontrado: {caminho_csv}")
        df = pd.read_csv(caminho_csv, dtype=COLUNAS_TEXTO)
        conn.execute(f"DELETE FROM {tabela};")
        df.to_sql(tabela, conn, if_exists="append", index=False)


def contar_tabelas_dw(conn: sqlite3.Connection) -> dict[str, int]:
    tabelas = [
        "dw_dim_tempo",
        "dw_dim_cliente",
        "dw_dim_produto",
        "dw_dim_vendedor",
        "dw_dim_pagamento",
        "dw_fato_pedidos",
        "dw_fato_itens_pedido",
    ]
    return {t: conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in tabelas}


def imprimir_auditoria_limpeza(conn: sqlite3.Connection, data_inicio: str, data_fim: str) -> None:
    q = lambda sql: conn.execute(sql, (data_inicio, data_fim)).fetchone()[0]
    q_sem_param = lambda sql: conn.execute(sql).fetchone()[0]

    total_pedidos = q("SELECT COUNT(*) FROM stg_orders WHERE order_purchase_timestamp BETWEEN ? AND ?")
    clientes_brutos = q("""
        SELECT COUNT(*) FROM stg_customers c
        JOIN stg_orders o ON o.customer_id = c.customer_id
        WHERE o.order_purchase_timestamp BETWEEN ? AND ?
    """)
    clientes_unicos = q("""
        SELECT COUNT(DISTINCT c.customer_unique_id) FROM stg_customers c
        JOIN stg_orders o ON o.customer_id = c.customer_id
        WHERE o.order_purchase_timestamp BETWEEN ? AND ?
    """)
    cidades_cli_alt = q("""
        SELECT COUNT(*) FROM stg_customers c
        JOIN stg_orders o ON o.customer_id = c.customer_id
        WHERE o.order_purchase_timestamp BETWEEN ? AND ?
          AND c.customer_city IS NOT NULL
          AND c.customer_city <> NORMALIZAR_CIDADE(c.customer_city)
    """)
    cidades_vend_alt = q("""
        SELECT COUNT(DISTINCT s.seller_id) FROM stg_sellers s
        JOIN stg_order_items oi ON oi.seller_id = s.seller_id
        JOIN stg_orders o ON o.order_id = oi.order_id
        WHERE o.order_purchase_timestamp BETWEEN ? AND ?
          AND s.seller_city IS NOT NULL
          AND s.seller_city <> NORMALIZAR_CIDADE(s.seller_city)
    """)
    geo_bruta = q_sem_param("SELECT COUNT(*) FROM stg_geolocation")
    geo_ceps = q_sem_param("SELECT COUNT(DISTINCT printf('%05d', CAST(geolocation_zip_code_prefix AS INTEGER))) FROM stg_geolocation")
    prod_sem_cat = q("""
        SELECT COUNT(DISTINCT p.product_id) FROM stg_products p
        JOIN stg_order_items oi ON oi.product_id = p.product_id
        JOIN stg_orders o ON o.order_id = oi.order_id
        WHERE o.order_purchase_timestamp BETWEEN ? AND ?
          AND NULLIF(TRIM(p.product_category_name), '') IS NULL
    """)
    prod_sem_trad = q("""
        SELECT COUNT(DISTINCT p.product_id) FROM stg_products p
        JOIN stg_order_items oi ON oi.product_id = p.product_id
        JOIN stg_orders o ON o.order_id = oi.order_id
        LEFT JOIN stg_category_translation t ON TRIM(t.product_category_name) = TRIM(p.product_category_name)
        WHERE o.order_purchase_timestamp BETWEEN ? AND ?
          AND NULLIF(TRIM(p.product_category_name), '') IS NOT NULL
          AND t.product_category_name_english IS NULL
    """)
    reviews_brutos = q("""
        SELECT COUNT(*) FROM stg_order_reviews r
        JOIN stg_orders o ON o.order_id = r.order_id
        WHERE o.order_purchase_timestamp BETWEEN ? AND ?
    """)
    reviews_unicos = q("""
        SELECT COUNT(*) FROM (
            SELECT DISTINCT r.review_id, r.order_id FROM stg_order_reviews r
            JOIN stg_orders o ON o.order_id = r.order_id
            WHERE o.order_purchase_timestamp BETWEEN ? AND ?
        )
    """)
    sem_aprovacao = q("""
        SELECT COUNT(*) FROM stg_orders
        WHERE order_purchase_timestamp BETWEEN ? AND ?
          AND (order_approved_at IS NULL OR TRIM(order_approved_at) = '')
    """)
    sem_entrega = q("""
        SELECT COUNT(*) FROM stg_orders
        WHERE order_purchase_timestamp BETWEEN ? AND ?
          AND (order_delivered_customer_date IS NULL OR TRIM(order_delivered_customer_date) = '')
    """)
    multi_pagamento = q("""
        SELECT COUNT(*) FROM (
            SELECT op.order_id FROM stg_order_payments op
            JOIN stg_orders o ON o.order_id = op.order_id
            WHERE o.order_purchase_timestamp BETWEEN ? AND ?
            GROUP BY op.order_id HAVING COUNT(*) > 1
        )
    """)

    print("\n--- AUDITORIA DE LIMPEZA (LINHAS AFETADAS NO LOTE) ---")
    print(f"Pedidos no lote:                                  {total_pedidos}")
    print(f"Clientes deduplicados (customer_id -> unique_id): {clientes_brutos - clientes_unicos}")
    print(f"Cidades de clientes padronizadas:                 {cidades_cli_alt}")
    print(f"Cidades de vendedores padronizadas:               {cidades_vend_alt}")
    print(f"Geolocalizacao colapsada por CEP:                 {geo_bruta - geo_ceps}")
    print(f"Produtos sem categoria -> 'sem_categoria':        {prod_sem_cat}")
    print(f"Produtos sem traducao -> fallback PT-BR:          {prod_sem_trad}")
    print(f"Avaliacoes duplicadas removidas:                  {reviews_brutos - reviews_unicos}")
    print(f"Pedidos sem aprovacao -> sk_tempo = -1:           {sem_aprovacao}")
    print(f"Pedidos sem entrega -> sk_tempo = -1:             {sem_entrega}")
    print(f"Pedidos com multiplos pagamentos:                 {multi_pagamento}")


def executar_lote(conn: sqlite3.Connection, nome_lote: str, data_inicio: str, data_fim: str) -> None:
    antes = contar_tabelas_dw(conn)
    conn.execute("DROP TABLE IF EXISTS temp._etl_parametros;")
    conn.execute("CREATE TEMP TABLE _etl_parametros (data_inicio TEXT, data_fim TEXT);")
    conn.execute("INSERT INTO _etl_parametros VALUES (?, ?);", (data_inicio, data_fim))

    sql_etl = (RAIZ / "etl" / "etl_dw.sql").read_text(encoding="utf-8")
    conn.executescript(sql_etl)
    conn.commit()

    depois = contar_tabelas_dw(conn)
    print(f"\n=== {nome_lote.upper()} ({data_inicio[:10]} a {data_fim[:10]}) ===")
    for tabela in depois:
        delta = depois[tabela] - antes[tabela]
        print(f"  {tabela:<24} | Antes: {antes[tabela]:>7} | Depois: {depois[tabela]:>7} | Inseridos: +{delta}")

    imprimir_auditoria_limpeza(conn, data_inicio, data_fim)


def main() -> None:
    parser = argparse.ArgumentParser(description="Orquestrador ETL - Data Warehouse Olist")
    parser.add_argument(
        "--modo",
        choices=["inicial", "incremental", "completo"],
        default="completo",
        help="inicial (ate 31/12/2017), incremental (2018) ou completo (ambos em sequencia)",
    )
    args = parser.parse_args()

    if args.modo in ("inicial", "completo") and DB_PATH.exists():
        DB_PATH.unlink()

    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.create_function("NORMALIZAR_CIDADE", 1, normalizar_cidade)

        print("1. Carregando CSVs na Staging...")
        carregar_staging(conn)

        print("2. Criando tabelas do DW e indices...")
        conn.executescript((RAIZ / "ddl" / "02_create_dw.sql").read_text(encoding="utf-8"))
        if (RAIZ / "ddl" / "03_indices.sql").exists():
            conn.executescript((RAIZ / "ddl" / "03_indices.sql").read_text(encoding="utf-8"))

        if args.modo in ("inicial", "completo"):
            executar_lote(conn, "Carga Inicial (2016-2017)", "1900-01-01 00:00:00", "2017-12-31 23:59:59")

        if args.modo in ("incremental", "completo"):
            executar_lote(conn, "Carga Incremental (2018)", "2018-01-01 00:00:00", "2099-12-31 23:59:59")

        erros_fk = conn.execute("PRAGMA foreign_key_check;").fetchall()
        if erros_fk:
            raise RuntimeError(f"Falha na integridade referencial: {erros_fk[:5]}")
        print("\nValidacao PRAGMA foreign_key_check: OK (0 violacoes).")


if __name__ == "__main__":
    main()