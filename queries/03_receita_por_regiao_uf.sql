-- faturamento, clientes únicos e ticket médio por região e UF do cliente \Vendas/

SELECT
    c.regiao,
    c.uf,
    COUNT(DISTINCT f.sk_cliente) AS clientes_unicos,
    COUNT(f.sk_fato_pedido) AS total_pedidos,
    ROUND(SUM(f.valor_total_pago), 2) AS faturamento_total,
    ROUND(AVG(f.valor_total_pago), 2) AS ticket_medio
FROM dw_fato_pedidos f
JOIN dw_dim_cliente c ON f.sk_cliente = c.sk_cliente
WHERE f.sk_cliente <> -1
  AND f.status_pedido NOT IN ('canceled', 'unavailable')
GROUP BY c.regiao, c.uf
ORDER BY faturamento_total DESC
LIMIT 10;