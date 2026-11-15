PRAGMA foreign_keys = ON;

-- dim_tempo
WITH RECURSIVE datas(dt) AS (
    SELECT '2016-09-01'
    UNION ALL
    SELECT date(dt, '+1 day') FROM datas WHERE dt < '2018-12-31'
),
feriados(dt, nome) AS (
    VALUES
        ('2016-09-07', 'Independencia do Brasil'),
        ('2016-10-12', 'Nossa Senhora Aparecida'),
        ('2016-11-02', 'Finados'),
        ('2016-11-15', 'Proclamacao da Republica'),
        ('2016-12-25', 'Natal'),
        ('2017-01-01', 'Confraternizacao Universal'),
        ('2017-02-28', 'Carnaval'),
        ('2017-04-14', 'Sexta-feira Santa'),
        ('2017-04-21', 'Tiradentes'),
        ('2017-05-01', 'Dia do Trabalho'),
        ('2017-06-15', 'Corpus Christi'),
        ('2017-09-07', 'Independencia do Brasil'),
        ('2017-10-12', 'Nossa Senhora Aparecida'),
        ('2017-11-02', 'Finados'),
        ('2017-11-15', 'Proclamacao da Republica'),
        ('2017-12-25', 'Natal'),
        ('2018-01-01', 'Confraternizacao Universal'),
        ('2018-02-13', 'Carnaval'),
        ('2018-03-30', 'Sexta-feira Santa'),
        ('2018-04-21', 'Tiradentes'),
        ('2018-05-01', 'Dia do Trabalho'),
        ('2018-05-31', 'Corpus Christi'),
        ('2018-09-07', 'Independencia do Brasil'),
        ('2018-10-12', 'Nossa Senhora Aparecida'),
        ('2018-11-02', 'Finados'),
        ('2018-11-15', 'Proclamacao da Republica'),
        ('2018-12-25', 'Natal')
)
INSERT OR IGNORE INTO dw_dim_tempo (
    sk_tempo, nk_data, dia, mes, nome_mes, trimestre, semestre,
    ano, dia_semana, eh_fim_de_semana, eh_feriado_nacional, nome_feriado
)
SELECT
    CAST(strftime('%Y%m%d', d.dt) AS INTEGER),
    d.dt,
    CAST(strftime('%d', d.dt) AS INTEGER),
    CAST(strftime('%m', d.dt) AS INTEGER),
    CASE CAST(strftime('%m', d.dt) AS INTEGER)
        WHEN 1 THEN 'Janeiro'
        WHEN 2 THEN 'Fevereiro'
        WHEN 3 THEN 'Marco'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Maio'
        WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro'
        WHEN 11 THEN 'Novembro'
        WHEN 12 THEN 'Dezembro'
    END,
    ((CAST(strftime('%m', d.dt) AS INTEGER) - 1) / 3) + 1,
    CASE WHEN CAST(strftime('%m', d.dt) AS INTEGER) <= 6 THEN 1 ELSE 2 END,
    CAST(strftime('%Y', d.dt) AS INTEGER),
    CASE CAST(strftime('%w', d.dt) AS INTEGER)
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Segunda-feira'
        WHEN 2 THEN 'Terca-feira'
        WHEN 3 THEN 'Quarta-feira'
        WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sabado'
    END,
    CASE WHEN CAST(strftime('%w', d.dt) AS INTEGER) IN (0, 6) THEN 1 ELSE 0 END,
    CASE WHEN f.nome IS NOT NULL THEN 1 ELSE 0 END,
    COALESCE(f.nome, 'Nao Aplicavel')
FROM datas d
LEFT JOIN feriados f ON d.dt = f.dt;

-- dim_pagamento
INSERT OR IGNORE INTO dw_dim_pagamento (nk_tipo_pagamento, descricao_pagamento)
SELECT DISTINCT
    TRIM(payment_type),
    CASE TRIM(payment_type)
        WHEN 'credit_card' THEN 'Cartao de Credito'
        WHEN 'boleto' THEN 'Boleto Bancario'
        WHEN 'voucher' THEN 'Voucher'
        WHEN 'debit_card' THEN 'Cartao de Debito'
        WHEN 'not_defined' THEN 'Nao Definido'
        ELSE TRIM(payment_type)
    END
FROM stg_order_payments
WHERE payment_type IS NOT NULL AND TRIM(payment_type) != '';

-- dim_produto
INSERT OR IGNORE INTO dw_dim_produto (
    nk_product_id, categoria_pt, categoria_en,
    peso_g, comprimento_cm, altura_cm, largura_cm, qtd_fotos
)
SELECT
    p.product_id,
    COALESCE(NULLIF(TRIM(p.product_category_name), ''), 'sem_categoria'),
    COALESCE(
        NULLIF(TRIM(t.product_category_name_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'uncategorized'
    ),
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    CAST(p.product_photos_qty AS INTEGER)
FROM stg_products p
LEFT JOIN stg_category_translation t
    ON TRIM(p.product_category_name) = TRIM(t.product_category_name);

-- dim_cliente (mantem o endereco do pedido mais recente por customer_unique_id)
WITH geo AS (
    SELECT
        printf('%05d', CAST(geolocation_zip_code_prefix AS INTEGER)) AS cep,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM stg_geolocation
    WHERE geolocation_zip_code_prefix IS NOT NULL
    GROUP BY cep
),
clientes AS (
    SELECT
        c.customer_unique_id,
        printf('%05d', CAST(c.customer_zip_code_prefix AS INTEGER)) AS cep,
        TRIM(c.customer_city) AS cidade,
        UPPER(TRIM(c.customer_state)) AS uf,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp DESC, c.customer_id DESC
        ) AS rn
    FROM stg_customers c
    LEFT JOIN stg_orders o ON c.customer_id = o.customer_id
)
INSERT OR IGNORE INTO dw_dim_cliente (
    nk_customer_unique_id, cep_prefixo, cidade, uf, regiao, latitude, longitude
)
SELECT
    c.customer_unique_id,
    c.cep,
    c.cidade,
    c.uf,
    CASE
        WHEN c.uf IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
        WHEN c.uf IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
        WHEN c.uf IN ('DF', 'GO', 'MT', 'MS') THEN 'Centro-Oeste'
        WHEN c.uf IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
        WHEN c.uf IN ('PR', 'RS', 'SC') THEN 'Sul'
        ELSE 'Desconhecido'
    END,
    g.lat,
    g.lng
FROM clientes c
LEFT JOIN geo g ON c.cep = g.cep
WHERE c.rn = 1;

-- dim_vendedor
WITH geo AS (
    SELECT
        printf('%05d', CAST(geolocation_zip_code_prefix AS INTEGER)) AS cep,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM stg_geolocation
    WHERE geolocation_zip_code_prefix IS NOT NULL
    GROUP BY cep
)
INSERT OR IGNORE INTO dw_dim_vendedor (
    nk_seller_id, cep_prefixo, cidade, uf, regiao, latitude, longitude
)
SELECT
    s.seller_id,
    printf('%05d', CAST(s.seller_zip_code_prefix AS INTEGER)),
    TRIM(s.seller_city),
    UPPER(TRIM(s.seller_state)),
    CASE
        WHEN UPPER(TRIM(s.seller_state)) IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
        WHEN UPPER(TRIM(s.seller_state)) IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
        WHEN UPPER(TRIM(s.seller_state)) IN ('DF', 'GO', 'MT', 'MS') THEN 'Centro-Oeste'
        WHEN UPPER(TRIM(s.seller_state)) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
        WHEN UPPER(TRIM(s.seller_state)) IN ('PR', 'RS', 'SC') THEN 'Sul'
        ELSE 'Desconhecido'
    END,
    g.lat,
    g.lng
FROM stg_sellers s
LEFT JOIN geo g
    ON printf('%05d', CAST(s.seller_zip_code_prefix AS INTEGER)) = g.cep;

-- fato_itens_pedido
INSERT OR IGNORE INTO dw_fato_itens_pedido (
    sk_tempo_compra, sk_tempo_aprovacao, sk_cliente, sk_produto, sk_vendedor,
    nk_order_id, order_item_id, quantidade, valor_item, valor_frete, valor_total_item
)
SELECT
    COALESCE(tc.sk_tempo, -1),
    COALESCE(ta.sk_tempo, -1),
    COALESCE(dc.sk_cliente, -1),
    COALESCE(dp.sk_produto, -1),
    COALESCE(dv.sk_vendedor, -1),
    i.order_id,
    i.order_item_id,
    1,
    i.price,
    i.freight_value,
    ROUND(i.price + i.freight_value, 2)
FROM stg_order_items i
JOIN stg_orders o ON i.order_id = o.order_id
LEFT JOIN stg_customers c ON o.customer_id = c.customer_id
LEFT JOIN dw_dim_cliente dc ON c.customer_unique_id = dc.nk_customer_unique_id
LEFT JOIN dw_dim_produto dp ON i.product_id = dp.nk_product_id
LEFT JOIN dw_dim_vendedor dv ON i.seller_id = dv.nk_seller_id
LEFT JOIN dw_dim_tempo tc ON SUBSTR(o.order_purchase_timestamp, 1, 10) = tc.nk_data
LEFT JOIN dw_dim_tempo ta ON SUBSTR(o.order_approved_at, 1, 10) = ta.nk_data;

-- fato_pedidos
WITH itens AS (
    SELECT order_id, COUNT(*) AS qtd
    FROM stg_order_items
    GROUP BY order_id
),
pagamentos AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_pago,
        MAX(payment_installments) AS parcelas
    FROM stg_order_payments
    GROUP BY order_id
),
pagamento_principal AS (
    SELECT
        order_id,
        TRIM(payment_type) AS tipo,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY payment_value DESC, payment_sequential ASC
        ) AS rn
    FROM stg_order_payments
),
avaliacoes AS (
    SELECT order_id, ROUND(AVG(review_score), 2) AS media_nota
    FROM stg_order_reviews
    GROUP BY order_id
)
INSERT OR IGNORE INTO dw_fato_pedidos (
    sk_tempo_compra, sk_tempo_aprovacao, sk_tempo_entrega, sk_tempo_estimativa,
    sk_cliente, sk_pagamento, nk_order_id, status_pedido,
    valor_total_pago, qtd_itens, qtd_parcelas,
    tempo_entrega_dias, dias_atraso, nota_avaliacao
)
SELECT
    COALESCE(tc.sk_tempo, -1),
    COALESCE(ta.sk_tempo, -1),
    COALESCE(te.sk_tempo, -1),
    COALESCE(test.sk_tempo, -1),
    COALESCE(dc.sk_cliente, -1),
    COALESCE(dpg.sk_pagamento, -1),
    o.order_id,
    o.order_status,
    ROUND(COALESCE(pg.total_pago, 0.0), 2),
    COALESCE(it.qtd, 0),
    COALESCE(pg.parcelas, 0),
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL AND TRIM(o.order_delivered_customer_date) != ''
        THEN ROUND(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp), 2)
    END,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL AND TRIM(o.order_delivered_customer_date) != ''
        THEN ROUND(julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date), 2)
    END,
    av.media_nota
FROM stg_orders o
LEFT JOIN stg_customers c ON o.customer_id = c.customer_id
LEFT JOIN dw_dim_cliente dc ON c.customer_unique_id = dc.nk_customer_unique_id
LEFT JOIN itens it ON o.order_id = it.order_id
LEFT JOIN pagamentos pg ON o.order_id = pg.order_id
LEFT JOIN pagamento_principal pp ON o.order_id = pp.order_id AND pp.rn = 1
LEFT JOIN dw_dim_pagamento dpg ON pp.tipo = dpg.nk_tipo_pagamento
LEFT JOIN avaliacoes av ON o.order_id = av.order_id
LEFT JOIN dw_dim_tempo tc ON SUBSTR(o.order_purchase_timestamp, 1, 10) = tc.nk_data
LEFT JOIN dw_dim_tempo ta ON SUBSTR(o.order_approved_at, 1, 10) = ta.nk_data
LEFT JOIN dw_dim_tempo te ON SUBSTR(o.order_delivered_customer_date, 1, 10) = te.nk_data
LEFT JOIN dw_dim_tempo test ON SUBSTR(o.order_estimated_delivery_date, 1, 10) = test.nk_data;