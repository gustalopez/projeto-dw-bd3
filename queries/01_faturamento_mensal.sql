-- evolução mensal de pedidos, faturamento e ticket médio \Vendas/

SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    COUNT(f.sk_fato_pedido) AS total_pedidos,
    ROUND(SUM(f.valor_total_pago), 2) AS faturamento_total,
    ROUND(AVG(f.valor_total_pago), 2) AS ticket_medio
FROM dw_fato_pedidos f
JOIN dw_dim_tempo t ON f.sk_tempo_compra = t.sk_tempo
WHERE f.sk_tempo_compra <> -1
  AND f.status_pedido NOT IN ('canceled', 'unavailable')
GROUP BY t.ano, t.mes, t.nome_mes
ORDER BY t.ano, t.mes;