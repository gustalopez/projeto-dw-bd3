-- top 10 categorias em receita de produtos, volume vendido e percentual de frete \Vendas/

SELECT
    p.categoria_pt,
    p.categoria_en,
    SUM(fi.quantidade) AS itens_vendidos,
    ROUND(SUM(fi.valor_item), 2) AS receita_produtos,
    ROUND(SUM(fi.valor_frete), 2) AS receita_frete,
    ROUND(100.0 * SUM(fi.valor_frete) / NULLIF(SUM(fi.valor_total_item), 0), 2) AS pct_frete_no_total
FROM dw_fato_itens_pedido fi
JOIN dw_dim_produto p ON fi.sk_produto = p.sk_produto
GROUP BY p.categoria_pt, p.categoria_en
ORDER BY receita_produtos DESC
LIMIT 10;