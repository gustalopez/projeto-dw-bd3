-- comparativo de pedidos e ticket médio entre dias úteis, fins de semana e feriados \Vendas | Calendário/

SELECT
    CASE
        WHEN t.eh_feriado_nacional = 1 THEN 'Feriado Nacional'
        WHEN t.eh_fim_de_semana = 1 THEN 'Fim de Semana'
        ELSE 'Dia Util'
    END AS tipo_dia,
    COUNT(DISTINCT t.sk_tempo) AS dias_no_periodo,
    COUNT(f.sk_fato_pedido) AS total_pedidos,
    ROUND(CAST(COUNT(f.sk_fato_pedido) AS REAL) / NULLIF(COUNT(DISTINCT t.sk_tempo), 0), 2) AS media_pedidos_por_dia,
    ROUND(AVG(f.valor_total_pago), 2) AS ticket_medio
FROM dw_dim_tempo t
LEFT JOIN dw_fato_pedidos f
       ON f.sk_tempo_compra = t.sk_tempo
      AND f.status_pedido NOT IN ('canceled', 'unavailable')
WHERE t.sk_tempo <> -1
GROUP BY tipo_dia
ORDER BY media_pedidos_por_dia DESC;