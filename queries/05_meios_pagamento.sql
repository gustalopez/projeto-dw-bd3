-- participação dos meios de pagamento no faturamento, ticket médio e parcelamento \Pagamentos/

SELECT
    pg.descricao_pagamento,
    COUNT(f.sk_fato_pedido) AS total_pedidos,
    ROUND(100.0 * COUNT(f.sk_fato_pedido) / SUM(COUNT(f.sk_fato_pedido)) OVER (), 2) AS pct_pedidos,
    ROUND(SUM(f.valor_total_pago), 2) AS volume_financeiro,
    ROUND(AVG(f.valor_total_pago), 2) AS ticket_medio,
    ROUND(AVG(f.qtd_parcelas), 2) AS media_parcelas
FROM dw_fato_pedidos f
JOIN dw_dim_pagamento pg ON f.sk_pagamento = pg.sk_pagamento
WHERE f.sk_pagamento <> -1
  AND f.status_pedido NOT IN ('canceled', 'unavailable')
GROUP BY pg.descricao_pagamento
ORDER BY volume_financeiro DESC;