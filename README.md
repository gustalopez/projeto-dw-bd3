# Data Warehouse - Olist

Pipeline de ETL e modelagem dimensional (esquema estrela) construídos em SQLite e Python a partir do dataset público de e-commerce da Olist.

## Visão geral

Os dados brutos dos CSVs são carregados primeiro em tabelas de staging (`stg_*`) sem alteração de conteúdo, mantendo os prefixos de CEP como texto para não perder zeros à esquerda. Em seguida, o script SQL faz a limpeza, deduplicação e carga nas tabelas do Data Warehouse (`dw_*`), suportando carga inicial (até `31/12/2017`) e carga incremental (`2018`).

Algumas decisões tomadas no ETL para lidar com inconsistências da base original:
- Uso de registros sentinela com chave `-1` nas dimensões para evitar chaves estrangeiras nulas (como pedidos cancelados sem data de entrega ou aprovação).
- Deduplicação de `customer_unique_id` na dimensão de clientes mantendo o endereço da compra mais recente e atualizando clientes recorrentes via `ON CONFLICT DO UPDATE`.
- Padronização de grafia de cidades (`NORMALIZAR_CIDADE`, removendo acentos, espaços extras e uniformizando em caixa alta) nas dimensões de clientes e vendedores.
- Deduplicação de avaliações (`review_id`) antes do cálculo da nota média por pedido.
- Consolidação de pedidos com múltiplos pagamentos somando o valor total pago e selecionando o meio de pagamento de maior valor como principal.
- Preenchimento padrão (`sem_categoria`) para produtos sem categoria e fallback para o nome em português nas categorias que não constam na tabela de tradução (`pc_gamer` e `portateis_cozinha_e_preparadores_de_alimentos`).

## Modelo dimensional

![Modelo Dimensional](m_estrela.png)

### Tabelas do DW

- **`dw_dim_tempo`**: calendário de `2016-09-01` a `2018-12-31` (`sk_tempo` no formato `YYYYMMDD`), hierarquia de data, dia da semana, fim de semana e feriados nacionais.
- **`dw_dim_cliente`**: clientes únicos (`nk_customer_unique_id`) com prefixo de CEP de 5 dígitos, cidade, UF, macrorregião e coordenadas médias (`latitude`, `longitude`).
- **`dw_dim_produto`**: produtos (`nk_product_id`) com categoria em português/inglês, dimensões físicas e quantidade de fotos.
- **`dw_dim_vendedor`**: lojistas (`nk_seller_id`) com localização, macrorregião e coordenadas médias por prefixo de CEP.
- **`dw_dim_pagamento`**: meios de pagamento (`credit_card`, `boleto`, `voucher`, `debit_card`, `not_defined`) e descrição em português.
- **`dw_fato_pedidos`** (1 linha por pedido): relaciona o pedido às datas de compra, aprovação, entrega e estimativa, cliente e meio de pagamento principal, armazenando `valor_total_pago`, `qtd_itens`, `qtd_parcelas`, `tempo_entrega_dias`, `dias_atraso` e `nota_avaliacao`.
- **`dw_fato_itens_pedido`** (1 linha por item do pedido): relaciona cada item às datas de compra e aprovação, cliente, produto e vendedor, armazenando `quantidade`, `valor_item`, `valor_frete` e `valor_total_item`.

## Organização das pastas

```text
projeto-dw-olist/
├── data/                                    # CSVs originais do Kaggle (ignorados no git)
├── ddl/
│   ├── 01_create_staging.sql                # Tabelas de staging
│   ├── 02_create_dw.sql                     # Tabelas do DW e registros sentinela (-1)
│   └── 03_indices.sql                       # Índices nas chaves estrangeiras e filtros das fatos
├── docs/
│   ├── m_estrela.png                        # Diagrama do esquema estrela
│   ├── parte1_modelagem.pdf                 # Relatório da Parte 1 (requisitos e modelagem)
│   └── partes2a5_relatorio.pdf              # Relatório das Partes 2 a 5 (ETL, SQL e desempenho)
├── etl/
│   ├── etl_dw.sql                           # Queries de transformação e carga (inicial/incremental)
│   ├── validacao.sql                        # Checagem manual de contagem e sentinelas
│   └── validar_e_benchmark.py               # Executa as 10 consultas e mede índices (EXPLAIN QUERY PLAN)
├── queries/
│   ├── 01_faturamento_mensal.sql            # Q01: Evolução mensal de pedidos, receita e ticket médio
│   ├── 02_top_categorias_receita.sql        # Q02: Top 10 categorias por receita e peso do frete
│   ├── 03_receita_por_regiao_uf.sql         # Q03: Faturamento e clientes únicos por região/UF
│   ├── 04_top_vendedores.sql                # Q04: Top 10 vendedores por faturamento e frete médio
│   ├── 05_meios_pagamento.sql               # Q05: Participação e parcelamento por meio de pagamento
│   ├── 06_sazonalidade_calendario.sql       # Q06: Demanda em dias úteis, fins de semana e feriados
│   ├── 07_prazo_entrega_atraso_regiao.sql   # Q07: Tempo de entrega e taxa de atraso por região
│   ├── 08_rotas_interestaduais_frete.sql    # Q08: Top 10 rotas logísticas, frete e peso médios
│   ├── 09_impacto_atraso_avaliacao.sql      # Q09: Impacto do atraso na nota média de avaliação
│   └── 10_satisfacao_status_trimestral.sql  # Q10: Evolução trimestral da satisfação e cancelamentos
├── executar_dw.py                           # Script que orquestra staging, carga inicial/incremental e FKs
├── m_estrela.png                            # Imagem do diagrama exibida neste README
└── requirements.txt
```

## Como rodar

1. Instale a dependência do Python:
```bash
pip install -r requirements.txt
```

2. Baixe a base *Brazilian E-Commerce Public Dataset by Olist* no Kaggle e extraia os 9 arquivos `.csv` dentro da pasta `data/`.

3. Execute o pipeline de ETL na raiz do repositório:
```bash
# Executa o ciclo completo (carga inicial até 31/12/2017 + incremental de 2018)
python executar_dw.py

# Ou execute por etapas (e repita o incremental para testar idempotência):
python executar_dw.py --modo inicial
python executar_dw.py --modo incremental
```

Ao final de cada carga, o script exibe a volumetria inserida, a auditoria de linhas afetadas por cada regra de limpeza e valida a integridade referencial com `PRAGMA foreign_key_check`.

4. Para executar as 10 consultas analíticas e rodar o comparativo de desempenho com e sem índices:
```bash
python etl/validar_e_benchmark.py
```