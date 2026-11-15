CREATE INDEX IF NOT EXISTS idx_fato_pedidos_tempo_compra ON dw_fato_pedidos(sk_tempo_compra);
CREATE INDEX IF NOT EXISTS idx_fato_pedidos_tempo_entrega ON dw_fato_pedidos(sk_tempo_entrega);
CREATE INDEX IF NOT EXISTS idx_fato_pedidos_cliente ON dw_fato_pedidos(sk_cliente);
CREATE INDEX IF NOT EXISTS idx_fato_pedidos_pagamento ON dw_fato_pedidos(sk_pagamento);
CREATE INDEX IF NOT EXISTS idx_fato_pedidos_status ON dw_fato_pedidos(status_pedido);

CREATE INDEX IF NOT EXISTS idx_fato_itens_tempo_compra ON dw_fato_itens_pedido(sk_tempo_compra);
CREATE INDEX IF NOT EXISTS idx_fato_itens_cliente ON dw_fato_itens_pedido(sk_cliente);
CREATE INDEX IF NOT EXISTS idx_fato_itens_produto ON dw_fato_itens_pedido(sk_produto);
CREATE INDEX IF NOT EXISTS idx_fato_itens_vendedor ON dw_fato_itens_pedido(sk_vendedor);