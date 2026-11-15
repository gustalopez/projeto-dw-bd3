-- tempo médio de entrega, folga em relação ao prazo estimado e taxa de atraso por região \Logística/

SELECT
    c.regiao,
    COUNT(f.sk_fato_pedido) AS pedidos_entregues,
    ROUND(AVG(f.tempo_entrega_dias), 2) AS media_dias_entrega,
    ROUND(AVG(f.dias_atraso), 2) AS media_diferenca_estimativa,
    SUM(CASE WHEN f.dias_atraso > 0 THEN 1 ELSE 0 END) AS qtd_atrasados,
    ROUND(100.0 * SUM(CASE WHEN f.dias_atraso > 0 THEN 1 ELSE 0 END) / NULLIF(COUNT(f.sk_fato_pedido), 0), 2) AS taxa_atraso_pct
FROM dw_fato_pedidos f
JOIN dw_dim_cliente c ON f.sk_cliente = c.sk_cliente
WHERE f.status_pedido = 'delivered'
  AND f.tempo_entrega_dias IS NOT NULL
  AND f.sk_cliente <> -1
GROUP BY c.regiao
ORDER BY taxa_atraso_pct DESC;