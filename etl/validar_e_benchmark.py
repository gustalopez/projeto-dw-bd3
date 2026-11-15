import sqlite3
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DB_PATH = RAIZ / "olist_dw.sqlite"
QUERIES_DIR = RAIZ / "queries"
INDICES_SQL = (RAIZ / "ddl" / "03_indices.sql").read_text(encoding="utf-8")


def imprimir_tabela(colunas: list[str], linhas: list[tuple]) -> None:
    larguras = [len(c) for c in colunas]
    for linha in linhas:
        for i, val in enumerate(linha):
            larguras[i] = max(larguras[i], len(str(val)))

    sep = "+-" + "-+-".join("-" * w for w in larguras) + "-+"
    cab = "| " + " | ".join(f"{c:<{larguras[i]}}" for i, c in enumerate(colunas)) + " |"
    print(sep)
    print(cab)
    print(sep)
    for linha in linhas:
        print("| " + " | ".join(f"{str(v):<{larguras[i]}}" for i, v in enumerate(linha)) + " |")
    print(sep)


def rodar_consultas_analiticas(conn: sqlite3.Connection) -> None:
    print("\n--- RESULTADOS DAS 10 CONSULTAS (PARTE 4) ---")
    # pega os arquivos de 01 a 10 em ordem
    for arquivo in sorted(QUERIES_DIR.glob("[0-9][0-9]_*.sql")):
        sql = arquivo.read_text(encoding="utf-8")
        cur = conn.execute(sql)
        colunas = [desc[0] for desc in cur.description]
        linhas = cur.fetchall()
        print(f"\n>>> {arquivo.name} ({len(linhas)} linhas)")
        imprimir_tabela(colunas, linhas)


def medir_tempo(conn: sqlite3.Connection, sql: str, repeticoes: int = 30) -> float:
    # roda 30 vezes pra tirar uma media mais estavel
    inicio = time.perf_counter()
    for _ in range(repeticoes):
        conn.execute(sql).fetchall()
    return ((time.perf_counter() - inicio) / repeticoes) * 1000.0


def benchmark_indices(conn: sqlite3.Connection) -> None:
    print("\n--- TESTE DE DESEMPENHO COM E SEM INDICES (PARTE 5) ---")
    consultas_teste = {
        "02_top_categorias_receita (Join Fato Itens -> Produto)": (QUERIES_DIR / "02_top_categorias_receita.sql").read_text(encoding="utf-8"),
        "07_prazo_entrega_atraso_regiao (Filtro Status + Join Cliente)": (QUERIES_DIR / "07_prazo_entrega_atraso_regiao.sql").read_text(encoding="utf-8"),
        "08_rotas_interestaduais_frete (Join Triplo Vendedor/Cliente/Produto)": (QUERIES_DIR / "08_rotas_interestaduais_frete.sql").read_text(encoding="utf-8"),
    }

    indices = [
        "idx_fato_pedidos_tempo_compra",
        "idx_fato_pedidos_tempo_entrega",
        "idx_fato_pedidos_cliente",
        "idx_fato_pedidos_pagamento",
        "idx_fato_pedidos_status",
        "idx_fato_itens_tempo_compra",
        "idx_fato_itens_cliente",
        "idx_fato_itens_produto",
        "idx_fato_itens_vendedor",
    ]

    # apaga os indices antes pra medir o banco sem otimizacao
    for idx in indices:
        conn.execute(f"DROP INDEX IF EXISTS {idx};")
    conn.commit()

    tempos_sem = {}
    planos_sem = {}
    for nome, sql in consultas_teste.items():
        tempos_sem[nome] = medir_tempo(conn, sql)
        planos_sem[nome] = [r[3] for r in conn.execute(f"EXPLAIN QUERY PLAN {sql}").fetchall()]

    # recria os indices e atualiza as estatisticas do sqlite
    conn.executescript(INDICES_SQL)
    conn.execute("ANALYZE;")
    conn.commit()

    tempos_com = {}
    planos_com = {}
    for nome, sql in consultas_teste.items():
        tempos_com[nome] = medir_tempo(conn, sql)
        planos_com[nome] = [r[3] for r in conn.execute(f"EXPLAIN QUERY PLAN {sql}").fetchall()]

    for nome in consultas_teste:
        ganho = ((tempos_sem[nome] - tempos_com[nome]) / tempos_sem[nome]) * 100.0
        print(f"\n--- {nome} ---")
        print(f"Tempo medio SEM indices: {tempos_sem[nome]:.2f} ms")
        print(f"Tempo medio COM indices: {tempos_com[nome]:.2f} ms (diferenca: {ganho:+.1f}%)")
        print("Plano SEM indices:")
        for p in planos_sem[nome]:
            print(f"  - {p}")
        print("Plano COM indices:")
        for p in planos_com[nome]:
            print(f"  - {p}")


if __name__ == "__main__":
    with sqlite3.connect(DB_PATH) as conn:
        rodar_consultas_analiticas(conn)
        benchmark_indices(conn)