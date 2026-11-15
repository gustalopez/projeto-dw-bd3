-- contagem de registros por tabela
SELECT 'dw_dim_tempo' AS tabela, COUNT(*) AS total FROM dw_dim_tempo
UNION ALL
SELECT 'dw_dim_cliente', COUNT(*) FROM dw_dim_cliente
UNION ALL
SELECT 'dw_dim_produto', COUNT(*) FROM dw_dim_produto
UNION ALL
SELECT 'dw_dim_vendedor', COUNT(*) FROM dw_dim_vendedor
UNION ALL
SELECT 'dw_dim_pagamento', COUNT(*) FROM dw_dim_pagamento
UNION ALL
SELECT 'dw_fato_itens_pedido', COUNT(*) FROM dw_fato_itens_pedido
UNION ALL
SELECT 'dw_fato_pedidos', COUNT(*) FROM dw_fato_pedidos;

-- verifica uso dos registros sentinela (-1) na fato_pedidos
SELECT
    COUNT(*) AS total_pedidos,
    SUM(CASE WHEN sk_tempo_aprovacao = -1 THEN 1 ELSE 0 END) AS sem_aprovacao,
    SUM(CASE WHEN sk_tempo_entrega = -1 THEN 1 ELSE 0 END) AS sem_entrega,
    SUM(CASE WHEN sk_pagamento = -1 THEN 1 ELSE 0 END) AS sem_pagamento,
    SUM(CASE WHEN sk_cliente = -1 THEN 1 ELSE 0 END) AS sem_cliente
FROM dw_fato_pedidos;