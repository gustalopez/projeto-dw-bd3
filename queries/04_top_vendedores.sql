-- top 10 vendedores por faturamento, volume de itens e frete médio \Vendas/

SELECT
    v.nk_seller_id,
    v.cidade,
    v.uf,
    COUNT(DISTINCT fi.nk_order_id) AS pedidos_atendidos,
    SUM(fi.quantidade) AS itens_vendidos,
    ROUND(SUM(fi.valor_item), 2) AS receita_produtos,
    ROUND(AVG(fi.valor_frete), 2) AS frete_medio
FROM dw_fato_itens_pedido fi
JOIN dw_dim_vendedor v ON fi.sk_vendedor = v.sk_vendedor
WHERE fi.sk_vendedor <> -1
GROUP BY v.nk_seller_id, v.cidade, v.uf
ORDER BY receita_produtos DESC
LIMIT 10;