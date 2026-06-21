-- =============================================================
-- GESTOR FINANCEIRO PESSOAL - DDL
-- Schema: dev_3aconsult
-- Rodar uma vez. Idempotente (ignora se tabela já existe).
-- =============================================================

-- Configurações gerais (chaves de API, etc.)
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_config (
    chave  VARCHAR2(100) PRIMARY KEY,
    valor  CLOB
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

-- Log de sincronizações com Pierre
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_sync_log (
    id                   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    synced_at            TIMESTAMP DEFAULT SYSTIMESTAMP,
    transactions_fetched NUMBER DEFAULT 0,
    transactions_new     NUMBER DEFAULT 0
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

-- Transações (cópia local do Pierre + status de revisão)
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_transacao (
    id                    VARCHAR2(200)  PRIMARY KEY,
    descricao             VARCHAR2(500),
    categoria_pierre      VARCHAR2(200),
    categoria_confirmada  VARCHAR2(200),
    valor                 NUMBER(15,2),
    saldo                 NUMBER(15,2),
    data_transacao        DATE,
    tipo                  VARCHAR2(50),
    status                VARCHAR2(50),
    conta_nome            VARCHAR2(200),
    conta_tipo            VARCHAR2(50),
    conta_subtipo         VARCHAR2(50),
    conta_nome_marketing  VARCHAR2(200),
    status_revisao        VARCHAR2(50) DEFAULT ''pending'',
    notas                 CLOB,
    criado_em             TIMESTAMP DEFAULT SYSTIMESTAMP
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

BEGIN EXECUTE IMMEDIATE '
  CREATE INDEX idx_gf_transacao_revisao ON gf_transacao (status_revisao)
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1408 THEN NULL; END IF; END;
/

-- Dívidas ativas (Creditas, Nubank, Mercado Pago, 99Julia...)
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_divida (
    id                  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome                VARCHAR2(200) NOT NULL,
    valor_total         NUMBER(15,2),
    valor_restante      NUMBER(15,2),
    parcela_mensal      NUMBER(15,2),
    dia_vencimento      NUMBER(2),
    parcelas_restantes  NUMBER,
    notas               CLOB,
    ativo               NUMBER(1) DEFAULT 1,
    criado_em           TIMESTAMP DEFAULT SYSTIMESTAMP
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

-- Reservas mensais para gastos não-recorrentes (sinking funds)
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_reserva (
    id                   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome                 VARCHAR2(200) NOT NULL,
    valor_meta           NUMBER(15,2),
    contribuicao_mensal  NUMBER(15,2),
    valor_atual          NUMBER(15,2) DEFAULT 0,
    data_meta            DATE,
    notas                CLOB,
    criado_em            TIMESTAMP DEFAULT SYSTIMESTAMP
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

-- Eventos futuros de caixa (receitas e despesas previstas)
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_evento_caixa (
    id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descricao      VARCHAR2(500) NOT NULL,
    valor          NUMBER(15,2),
    data_prevista  DATE,
    recorrencia    VARCHAR2(50),
    categoria      VARCHAR2(200),
    confirmado     NUMBER(1) DEFAULT 0,
    notas          CLOB
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

-- Memórias da IA (contexto aprendido entre conversas)
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_memoria (
    id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    chave        VARCHAR2(200) UNIQUE NOT NULL,
    descricao    VARCHAR2(500),
    valor        CLOB,
    criado_em    TIMESTAMP DEFAULT SYSTIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT SYSTIMESTAMP
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

-- Histórico de chat com o Finn
BEGIN EXECUTE IMMEDIATE '
  CREATE TABLE gf_chat_mensagem (
    id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role      VARCHAR2(20) NOT NULL,
    conteudo  CLOB NOT NULL,
    criado_em TIMESTAMP DEFAULT SYSTIMESTAMP
  )
'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

COMMIT;
