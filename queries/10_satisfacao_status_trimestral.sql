-- evolução trimestral da nota média de avaliação e taxa de cancelamento/indisponibilidade \Satisfação/

SELECT
    t.ano,
    t.trimestre,
    COUNT(f.sk_fato_pedido) AS total_pedidos,
    SUM(CASE WHEN f.status_pedido IN ('canceled', 'unavailable') THEN 1 ELSE 0 END) AS pedidos_cancelados_indisp,
    ROUND(100.0 * SUM(CASE WHEN f.status_pedido IN ('canceled', 'unavailable') THEN 1 ELSE 0 END) / NULLIF(COUNT(f.sk_fato_pedido), 0), 2) AS taxa_cancelamento_pct,
    ROUND(AVG(f.nota_avaliacao), 2) AS nota_media_avaliacao
FROM dw_fato_pedidos f
JOIN dw_dim_tempo t ON f.sk_tempo_compra = t.sk_tempo
WHERE f.sk_tempo_compra <> -1
GROUP BY t.ano, t.trimestre
ORDER BY t.ano, t.trimestre;