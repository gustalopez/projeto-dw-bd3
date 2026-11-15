-- faturamento e ticket medio por ano/mes (apenas pedidos entregues)
SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    COUNT(f.sk_fato_pedido) AS qtd_pedidos,
    ROUND(SUM(f.valor_total_pago), 2) AS faturamento,
    ROUND(AVG(f.valor_total_pago), 2) AS ticket_medio
FROM dw_fato_pedidos f
JOIN dw_dim_tempo t ON f.sk_tempo_compra = t.sk_tempo
WHERE f.status_pedido = 'delivered'
  AND t.sk_tempo <> -1
GROUP BY t.ano, t.mes, t.nome_mes
ORDER BY t.ano, t.mes;

-- top 10 categorias por receita de itens
SELECT
    p.categoria_pt,
    COUNT(fi.sk_fato_item) AS itens_vendidos,
    ROUND(SUM(fi.valor_item), 2) AS receita_produtos,
    ROUND(SUM(fi.valor_frete), 2) AS total_frete
FROM dw_fato_itens_pedido fi
JOIN dw_dim_produto p ON fi.sk_produto = p.sk_produto
GROUP BY p.categoria_pt
ORDER BY receita_produtos DESC
LIMIT 10;

-- prazo medio de entega, taxa de atraso e avaliacao por regiao do cliente
SELECT
    c.regiao,
    COUNT(f.sk_fato_pedido) AS pedidos_entregues,
    ROUND(AVG(f.tempo_entrega_dias), 1) AS media_dias_entrega,
    ROUND(100.0 * SUM(CASE WHEN f.dias_atraso > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_atraso,
    ROUND(AVG(f.nota_avaliacao), 2) AS media_avaliacao
FROM dw_fato_pedidos f
JOIN dw_dim_cliente c ON f.sk_cliente = c.sk_cliente
WHERE f.status_pedido = 'delivered'
  AND f.tempo_entrega_dias IS NOT NULL
GROUP BY c.regiao
ORDER BY pedidos_entregues DESC;

-- distribuicao por meio de pagamento
SELECT
    pg.descricao_pagamento,
    COUNT(f.sk_fato_pedido) AS qtd_pedidos,
    ROUND(SUM(f.valor_total_pago), 2) AS volume_pago,
    ROUND(AVG(f.qtd_parcelas), 1) AS media_parcelas
FROM dw_fato_pedidos f
JOIN dw_dim_pagamento pg ON f.sk_pagamento = pg.sk_pagamento
GROUP BY pg.descricao_pagamento
ORDER BY volume_pago DESC;