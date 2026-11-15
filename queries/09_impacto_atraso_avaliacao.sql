-- impacto do atraso na entrega sobre a nota média de avaliação dos clientes \Satisfação | Logística/

SELECT
    CASE
        WHEN f.dias_atraso <= 0 THEN 'Entregue no Prazo'
        WHEN f.dias_atraso > 0 AND f.dias_atraso <= 5 THEN 'Atraso Leve (1 a 5 dias)'
        ELSE 'Atraso Severo (> 5 dias)'
    END AS situacao_entrega,
    COUNT(f.sk_fato_pedido) AS total_pedidos_avaliados,
    ROUND(AVG(f.tempo_entrega_dias), 2) AS media_dias_entrega,
    ROUND(AVG(f.nota_avaliacao), 2) AS nota_media_avaliacao,
    ROUND(100.0 * SUM(CASE WHEN f.nota_avaliacao <= 2 THEN 1 ELSE 0 END) / NULLIF(COUNT(f.sk_fato_pedido), 0), 2) AS pct_notas_baixas
FROM dw_fato_pedidos f
WHERE f.status_pedido = 'delivered'
  AND f.dias_atraso IS NOT NULL
  AND f.nota_avaliacao IS NOT NULL
GROUP BY situacao_entrega
ORDER BY nota_media_avaliacao DESC;