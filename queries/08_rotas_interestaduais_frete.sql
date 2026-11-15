-- top 10 rotas (UF vendedor -> UF cliente) por volume de itens, frete médio e peso médio \Logística/

SELECT
    v.uf AS uf_origem,
    c.uf AS uf_destino,
    CASE WHEN v.uf = c.uf THEN 'Estadual' ELSE 'Interestadual' END AS tipo_rota,
    SUM(fi.quantidade) AS itens_transportados,
    ROUND(AVG(fi.valor_frete), 2) AS frete_medio,
    ROUND(AVG(p.peso_g), 1) AS peso_medio_g
FROM dw_fato_itens_pedido fi
JOIN dw_dim_vendedor v ON fi.sk_vendedor = v.sk_vendedor
JOIN dw_dim_cliente c ON fi.sk_cliente = c.sk_cliente
JOIN dw_dim_produto p ON fi.sk_produto = p.sk_produto
WHERE fi.sk_vendedor <> -1
  AND fi.sk_cliente <> -1
GROUP BY v.uf, c.uf, tipo_rota
ORDER BY itens_transportados DESC
LIMIT 10;