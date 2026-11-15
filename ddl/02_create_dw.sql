-- data warehouse (esquema estrela)
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS dw_dim_tempo (
    sk_tempo INTEGER PRIMARY KEY,
    nk_data TEXT UNIQUE NOT NULL,
    dia INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    nome_mes TEXT NOT NULL,
    trimestre INTEGER NOT NULL,
    semestre INTEGER NOT NULL,
    ano INTEGER NOT NULL,
    dia_semana TEXT NOT NULL,
    eh_fim_de_semana INTEGER NOT NULL,
    eh_feriado_nacional INTEGER NOT NULL,
    nome_feriado TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dw_dim_cliente (
    sk_cliente INTEGER PRIMARY KEY AUTOINCREMENT,
    nk_customer_unique_id TEXT UNIQUE NOT NULL,
    cep_prefixo TEXT NOT NULL,
    cidade TEXT NOT NULL,
    uf TEXT NOT NULL,
    regiao TEXT NOT NULL,
    latitude REAL,
    longitude REAL
);

CREATE TABLE IF NOT EXISTS dw_dim_produto (
    sk_produto INTEGER PRIMARY KEY AUTOINCREMENT,
    nk_product_id TEXT UNIQUE NOT NULL,
    categoria_pt TEXT NOT NULL,
    categoria_en TEXT NOT NULL,
    peso_g REAL,
    comprimento_cm REAL,
    altura_cm REAL,
    largura_cm REAL,
    qtd_fotos INTEGER
);

CREATE TABLE IF NOT EXISTS dw_dim_vendedor (
    sk_vendedor INTEGER PRIMARY KEY AUTOINCREMENT,
    nk_seller_id TEXT UNIQUE NOT NULL,
    cep_prefixo TEXT NOT NULL,
    cidade TEXT NOT NULL,
    uf TEXT NOT NULL,
    regiao TEXT NOT NULL,
    latitude REAL,
    longitude REAL
);

CREATE TABLE IF NOT EXISTS dw_dim_pagamento (
    sk_pagamento INTEGER PRIMARY KEY AUTOINCREMENT,
    nk_tipo_pagamento TEXT UNIQUE NOT NULL,
    descricao_pagamento TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dw_fato_itens_pedido (
    sk_fato_item INTEGER PRIMARY KEY AUTOINCREMENT,
    sk_tempo_compra INTEGER NOT NULL,
    sk_tempo_aprovacao INTEGER NOT NULL,
    sk_cliente INTEGER NOT NULL,
    sk_produto INTEGER NOT NULL,
    sk_vendedor INTEGER NOT NULL,
    nk_order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,
    quantidade INTEGER NOT NULL,
    valor_item REAL NOT NULL,
    valor_frete REAL NOT NULL,
    valor_total_item REAL NOT NULL,
    UNIQUE(nk_order_id, order_item_id),
    FOREIGN KEY (sk_tempo_compra) REFERENCES dw_dim_tempo(sk_tempo),
    FOREIGN KEY (sk_tempo_aprovacao) REFERENCES dw_dim_tempo(sk_tempo),
    FOREIGN KEY (sk_cliente) REFERENCES dw_dim_cliente(sk_cliente),
    FOREIGN KEY (sk_produto) REFERENCES dw_dim_produto(sk_produto),
    FOREIGN KEY (sk_vendedor) REFERENCES dw_dim_vendedor(sk_vendedor)
);

CREATE TABLE IF NOT EXISTS dw_fato_pedidos (
    sk_fato_pedido INTEGER PRIMARY KEY AUTOINCREMENT,
    sk_tempo_compra INTEGER NOT NULL,
    sk_tempo_aprovacao INTEGER NOT NULL,
    sk_tempo_entrega INTEGER NOT NULL,
    sk_tempo_estimativa INTEGER NOT NULL,
    sk_cliente INTEGER NOT NULL,
    sk_pagamento INTEGER NOT NULL,
    nk_order_id TEXT UNIQUE NOT NULL,
    status_pedido TEXT NOT NULL,
    valor_total_pago REAL NOT NULL,
    qtd_itens INTEGER NOT NULL,
    qtd_parcelas INTEGER NOT NULL,
    tempo_entrega_dias REAL,
    dias_atraso REAL,
    nota_avaliacao REAL,
    FOREIGN KEY (sk_tempo_compra) REFERENCES dw_dim_tempo(sk_tempo),
    FOREIGN KEY (sk_tempo_aprovacao) REFERENCES dw_dim_tempo(sk_tempo),
    FOREIGN KEY (sk_tempo_entrega) REFERENCES dw_dim_tempo(sk_tempo),
    FOREIGN KEY (sk_tempo_estimativa) REFERENCES dw_dim_tempo(sk_tempo),
    FOREIGN KEY (sk_cliente) REFERENCES dw_dim_cliente(sk_cliente),
    FOREIGN KEY (sk_pagamento) REFERENCES dw_dim_pagamento(sk_pagamento)
);

INSERT OR IGNORE INTO dw_dim_tempo (sk_tempo, nk_data, dia, mes, nome_mes, trimestre, semestre, ano, dia_semana, eh_fim_de_semana, eh_feriado_nacional, nome_feriado)
VALUES (-1, '1900-01-01', 1, 1, 'Desconhecido', 1, 1, 1900, 'Desconhecido', 0, 0, 'Nao Aplicavel');

INSERT OR IGNORE INTO dw_dim_cliente (sk_cliente, nk_customer_unique_id, cep_prefixo, cidade, uf, regiao, latitude, longitude)
VALUES (-1, 'DESCONHECIDO', '00000', 'Desconhecido', 'ND', 'Desconhecido', NULL, NULL);

INSERT OR IGNORE INTO dw_dim_produto (sk_produto, nk_product_id, categoria_pt, categoria_en, peso_g, comprimento_cm, altura_cm, largura_cm, qtd_fotos)
VALUES (-1, 'DESCONHECIDO', 'sem_categoria', 'uncategorized', 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO dw_dim_vendedor (sk_vendedor, nk_seller_id, cep_prefixo, cidade, uf, regiao, latitude, longitude)
VALUES (-1, 'DESCONHECIDO', '00000', 'Desconhecido', 'ND', 'Desconhecido', NULL, NULL);

INSERT OR IGNORE INTO dw_dim_pagamento (sk_pagamento, nk_tipo_pagamento, descricao_pagamento)
VALUES (-1, 'not_defined', 'Nao Definido');