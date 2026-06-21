-- =============================================================
-- CONFIGURAÇÃO INICIAL - Chaves de API
-- Rode depois de criar as tabelas (01_tables.sql)
-- Substitua os valores pelas suas chaves reais
-- =============================================================

MERGE INTO gf_config dst
USING (SELECT 'PIERRE_API_KEY'    chave, 'sk-SUA_CHAVE_PIERRE_AQUI'    valor FROM dual
       UNION ALL
       SELECT 'ANTHROPIC_API_KEY' chave, 'sk-ant-SUA_CHAVE_CLAUDE_AQUI' valor FROM dual) src
ON (dst.chave = src.chave)
WHEN MATCHED THEN UPDATE SET dst.valor = src.valor
WHEN NOT MATCHED THEN INSERT (chave, valor) VALUES (src.chave, src.valor);

COMMIT;

-- Seed inicial de dívidas (ajuste os valores conforme o momento atual)
-- INSERTs separados para evitar ORA-00918 do UNION ALL com NULLs sem alias
INSERT INTO gf_divida (nome, valor_total, valor_restante, parcela_mensal, dia_vencimento, parcelas_restantes, notas)
SELECT 'Creditas', 9120, 9120, NULL, NULL, NULL, 'Financiamento carro - quitação antecipada com venda da moto'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM gf_divida WHERE nome = 'Creditas');

INSERT INTO gf_divida (nome, valor_total, valor_restante, parcela_mensal, dia_vencimento, parcelas_restantes, notas)
SELECT 'Mercado Pago', 3200, 3200, NULL, NULL, NULL, 'Empréstimo pessoal - quitação antecipada'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM gf_divida WHERE nome = 'Mercado Pago');

INSERT INTO gf_divida (nome, valor_total, valor_restante, parcela_mensal, dia_vencimento, parcelas_restantes, notas)
SELECT 'Nubank Empréstimo', 3100, 3100, NULL, NULL, NULL, 'Empréstimo pessoal - quitação antecipada'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM gf_divida WHERE nome = 'Nubank Empréstimo');

INSERT INTO gf_divida (nome, valor_total, valor_restante, parcela_mensal, dia_vencimento, parcelas_restantes, notas)
SELECT '99Julia', 10800, 10800, 600, NULL, 18, 'Empréstimo em nome da Julia - amortizar com margem liberada'
FROM dual WHERE NOT EXISTS (SELECT 1 FROM gf_divida WHERE nome = '99Julia');

COMMIT;
