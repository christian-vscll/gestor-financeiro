-- =============================================================
-- PACKAGES PL/SQL - Pierre API + Claude AI
-- Schema: dev_3aconsult
-- =============================================================

-- ---------------------------------------------------------------
-- PKG_GF_PIERRE - Chamadas para a API do Pierre Finance
-- ---------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_gf_pierre AS
  FUNCTION  get_config(p_chave VARCHAR2) RETURN VARCHAR2;
  FUNCTION  call_get(p_path VARCHAR2, p_params VARCHAR2 DEFAULT NULL) RETURN CLOB;
  PROCEDURE sync_transacoes(p_resultado OUT CLOB);
  FUNCTION  get_saldo    RETURN CLOB;
  FUNCTION  get_contas   RETURN CLOB;
  FUNCTION  get_faturas  RETURN CLOB;
END pkg_gf_pierre;
/

CREATE OR REPLACE PACKAGE BODY pkg_gf_pierre AS

  C_BASE_URL CONSTANT VARCHAR2(100) := 'https://www.pierre.finance/tools/api/';

  FUNCTION get_config(p_chave VARCHAR2) RETURN VARCHAR2 IS
    v_valor VARCHAR2(4000);
  BEGIN
    SELECT valor INTO v_valor FROM gf_config WHERE chave = p_chave;
    RETURN v_valor;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
  END;

  FUNCTION call_get(p_path VARCHAR2, p_params VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_url  VARCHAR2(2000);
    l_resp CLOB;
  BEGIN
    l_url := C_BASE_URL || p_path;
    IF p_params IS NOT NULL THEN
      l_url := l_url || '?' || p_params;
    END IF;

    APEX_WEB_SERVICE.SET_REQUEST_HEADERS(
      p_name_01  => 'Authorization',
      p_value_01 => 'Bearer ' || get_config('PIERRE_API_KEY')
    );

    l_resp := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
      p_url         => l_url,
      p_http_method => 'GET'
    );
    RETURN l_resp;
  END;

  PROCEDURE sync_transacoes(p_resultado OUT CLOB) IS
    l_start_date VARCHAR2(20);
    l_end_date   VARCHAR2(20) := TO_CHAR(SYSDATE, 'YYYY-MM-DD');
    l_resp       CLOB;
    l_total      NUMBER := 0;
    l_novos      NUMBER := 0;
    l_count      NUMBER;
    l_n          NUMBER;
    l_txn_id     VARCHAR2(200);
    l_data_str   VARCHAR2(20);
  BEGIN
    -- CAST evita erro de aritmética com TIMESTAMP (DATE - NUMBER é válido, TIMESTAMP não)
    SELECT TO_CHAR(CAST(MAX(synced_at) AS DATE) - 1, 'YYYY-MM-DD')
      INTO l_start_date FROM gf_sync_log;

    IF l_start_date IS NULL THEN
      l_start_date := TO_CHAR(SYSDATE - 90, 'YYYY-MM-DD');
    END IF;

    l_resp := call_get('get-transactions',
      'startDate=' || l_start_date || '&endDate=' || l_end_date || '&format=raw');

    -- APEX_JSON evita limitação de JSON_TABLE com variável CLOB em cursor PL/SQL
    APEX_JSON.parse(l_resp);
    l_n := NVL(APEX_JSON.get_count(p_path => 'data'), 0);

    FOR i IN 1..l_n LOOP
      l_txn_id   := SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].id',   p0 => i), 1, 200);
      l_data_str := SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].date', p0 => i), 1, 20);
      l_total    := l_total + 1;

      SELECT COUNT(*) INTO l_count FROM gf_transacao WHERE id = l_txn_id;

      IF l_count = 0 THEN
        INSERT INTO gf_transacao (
          id, descricao, categoria_pierre, valor, saldo,
          data_transacao, tipo, status,
          conta_nome, conta_tipo, conta_subtipo, conta_nome_marketing,
          status_revisao
        ) VALUES (
          l_txn_id,
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].description',            p0 => i), 1, 500),
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].category',               p0 => i), 1, 200),
          APEX_JSON.get_number  (p_path => 'data[%d].amount',                 p0 => i),
          APEX_JSON.get_number  (p_path => 'data[%d].balance',                p0 => i),
          TO_DATE(l_data_str, 'YYYY-MM-DD'),
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].type',                   p0 => i), 1, 50),
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].status',                 p0 => i), 1, 50),
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].account_name',           p0 => i), 1, 200),
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].account_type',           p0 => i), 1, 50),
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].account_subtype',        p0 => i), 1, 50),
          SUBSTR(APEX_JSON.get_varchar2(p_path => 'data[%d].account_marketing_name', p0 => i), 1, 200),
          'pending'
        );
        l_novos := l_novos + 1;
      END IF;
    END LOOP;

    INSERT INTO gf_sync_log (transactions_fetched, transactions_new)
    VALUES (l_total, l_novos);

    COMMIT;

    APEX_JSON.initialize_clob_output;
    APEX_JSON.open_object;
    APEX_JSON.write('fetched',    l_total);
    APEX_JSON.write('new',        l_novos);
    APEX_JSON.write('start_date', l_start_date);
    APEX_JSON.write('end_date',   l_end_date);
    APEX_JSON.close_object;
    p_resultado := APEX_JSON.get_clob_output;
    APEX_JSON.free_output;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      APEX_JSON.initialize_clob_output;
      APEX_JSON.open_object;
      APEX_JSON.write('erro', SQLERRM);
      APEX_JSON.close_object;
      p_resultado := APEX_JSON.get_clob_output;
      APEX_JSON.free_output;
  END;

  FUNCTION get_saldo  RETURN CLOB IS BEGIN RETURN call_get('get-balance');  END;
  FUNCTION get_contas RETURN CLOB IS BEGIN RETURN call_get('get-accounts'); END;
  FUNCTION get_faturas RETURN CLOB IS BEGIN RETURN call_get('get-bills');   END;

END pkg_gf_pierre;
/


-- ---------------------------------------------------------------
-- PKG_GF_AI - Integração com Claude (Finn, o gerente financeiro)
-- ---------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_gf_ai AS
  PROCEDURE chat(p_mensagem IN VARCHAR2, p_resposta OUT CLOB);
  PROCEDURE checkin(p_resposta OUT CLOB);
END pkg_gf_ai;
/

CREATE OR REPLACE PACKAGE BODY pkg_gf_ai AS

  -- System prompt do Finn
  C_SYSTEM CONSTANT CLOB :=
    'Você é o Finn, gerente financeiro pessoal do Christian.' || CHR(10) ||
    '## Perfil' || CHR(10) ||
    '- Dev PJ (Oracle APEX, PL/SQL, Python, OCI)' || CHR(10) ||
    '- Renda PJ: Contabilidade (4 pagamentos/mês, datas variadas) + clientes TI Scafom e Othon (2 pagamentos/mês)' || CHR(10) ||
    '- Cartões: Inter (vence dia 15), Nubank (dia 15), Leroy (dia 17). Esposa: Julia.' || CHR(10) ||
    '## Dívidas em quitação (venda moto R$ 17.000)' || CHR(10) ||
    '- Creditas (carro/alienação): ~R$ 9.120 | Mercado Pago: ~R$ 3.200 | Nubank: ~R$ 3.100' || CHR(10) ||
    '- 99Julia (em nome da Julia): ~18x R$ 600, a amortizar' || CHR(10) ||
    '## Recorrentes conhecidos' || CHR(10) ||
    '- Assinaturas: TotalPass, Netflix, YouTube Premium, Apple (múltiplas), Claude.ai, Google Workspace' || CHR(10) ||
    '- Seguros: Suhai, Zurich | Pix Búzios: divisão viagem (6x R$ 475)' || CHR(10) ||
    '## Evento crítico' || CHR(10) ||
    '- Oliver (1º filho) nasce agosto/2026 → novas despesas fixas + únicas' || CHR(10) ||
    '## Seu papel' || CHR(10) ||
    '1. Categorizar com contexto real (além da sugestão automática do Pierre)' || CHR(10) ||
    '2. Identificar transações ambíguas e perguntar (máx 2 perguntas por vez)' || CHR(10) ||
    '3. Alertar sobre datas críticas, gastos incomuns, apertos de caixa' || CHR(10) ||
    '4. Acumular contexto entre conversas' || CHR(10) ||
    '## Estilo' || CHR(10) ||
    '- Direto, sem rodeios, português BR, proativo, sempre usa R$' || CHR(10) ||
    '- Check-in: resume o que mudou + aponta o que precisa de atenção';

  -- Monta contexto financeiro atual para injetar no prompt
  FUNCTION build_context RETURN CLOB IS
    l_ctx CLOB := '';
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM gf_transacao WHERE status_revisao = 'pending';
    IF l_cnt > 0 THEN
      l_ctx := l_ctx || '## Transações pendentes de revisão (' || l_cnt || ')' || CHR(10);
      FOR r IN (
        SELECT TO_CHAR(data_transacao, 'YYYY-MM-DD') dt, descricao, valor,
               NVL(categoria_pierre, 'Sem categoria') cat,
               NVL(conta_nome_marketing, conta_nome) conta
          FROM gf_transacao WHERE status_revisao = 'pending'
         ORDER BY data_transacao DESC FETCH FIRST 30 ROWS ONLY
      ) LOOP
        l_ctx := l_ctx ||
          '- [' || r.dt || '] ' || r.descricao || ' | ' ||
          CASE WHEN r.valor > 0 THEN '+' END ||
          'R$ ' || TO_CHAR(ABS(r.valor), 'FM999G990D00', 'NLS_NUMERIC_CHARACTERS=''.,''') || ' | ' ||
          'Pierre: ' || r.cat || ' | ' || r.conta || CHR(10);
      END LOOP;
    END IF;

    SELECT COUNT(*) INTO l_cnt FROM gf_divida WHERE ativo = 1;
    IF l_cnt > 0 THEN
      l_ctx := l_ctx || CHR(10) || '## Dívidas ativas' || CHR(10);
      FOR r IN (SELECT nome, valor_restante, parcela_mensal, dia_vencimento
                  FROM gf_divida WHERE ativo = 1) LOOP
        l_ctx := l_ctx ||
          '- ' || r.nome || ': R$ ' ||
          TO_CHAR(r.valor_restante, 'FM999G990D00', 'NLS_NUMERIC_CHARACTERS=''.,''') ||
          ' restantes | R$ ' ||
          TO_CHAR(NVL(r.parcela_mensal,0), 'FM999G990D00', 'NLS_NUMERIC_CHARACTERS=''.,''') ||
          '/mês | vence dia ' || NVL(TO_CHAR(r.dia_vencimento),'—') || CHR(10);
      END LOOP;
    END IF;

    SELECT COUNT(*) INTO l_cnt FROM gf_reserva;
    IF l_cnt > 0 THEN
      l_ctx := l_ctx || CHR(10) || '## Reservas (sinking funds)' || CHR(10);
      FOR r IN (SELECT nome, valor_atual, valor_meta FROM gf_reserva) LOOP
        l_ctx := l_ctx ||
          '- ' || r.nome || ': R$ ' ||
          TO_CHAR(r.valor_atual,'FM999G990D00','NLS_NUMERIC_CHARACTERS=''.,''') || ' / R$ ' ||
          TO_CHAR(r.valor_meta, 'FM999G990D00','NLS_NUMERIC_CHARACTERS=''.,''') || CHR(10);
      END LOOP;
    END IF;

    SELECT COUNT(*) INTO l_cnt FROM gf_memoria;
    IF l_cnt > 0 THEN
      l_ctx := l_ctx || CHR(10) || '## Contexto aprendido' || CHR(10);
      FOR r IN (SELECT chave, descricao FROM gf_memoria) LOOP
        l_ctx := l_ctx || '- ' || r.chave || ': ' || r.descricao || CHR(10);
      END LOOP;
    END IF;

    RETURN l_ctx;
  END;

  PROCEDURE chat(p_mensagem IN VARCHAR2, p_resposta OUT CLOB) IS
    l_context  CLOB;
    l_msg_clob CLOB;
    l_body     CLOB;
    l_resp     CLOB;
  BEGIN
    l_context := build_context;

    -- Mensagem atual com contexto injetado (CLOB evita truncamento em 32767)
    IF DBMS_LOB.GETLENGTH(l_context) > 0 THEN
      l_msg_clob := TO_CLOB(p_mensagem) || CHR(10) || CHR(10) ||
                    '---' || CHR(10) || '[Dados do sistema]' || CHR(10) || l_context;
    ELSE
      l_msg_clob := TO_CLOB(p_mensagem);
    END IF;

    -- Body da requisição via APEX_JSON (escaping correto para CLOBs e chars especiais)
    APEX_JSON.initialize_clob_output;
    APEX_JSON.open_object;
    APEX_JSON.write('model',      'claude-haiku-4-5-20251001');
    APEX_JSON.write('max_tokens', 2048);
    APEX_JSON.write('system',     C_SYSTEM);
    APEX_JSON.open_array('messages');

    -- Histórico (últimas 20 mensagens, ordem cronológica)
    FOR r IN (
      SELECT role, conteudo FROM (
        SELECT role, conteudo, criado_em FROM gf_chat_mensagem
         ORDER BY criado_em DESC FETCH FIRST 20 ROWS ONLY
      ) ORDER BY criado_em ASC
    ) LOOP
      APEX_JSON.open_object;
      APEX_JSON.write('role',    r.role);
      APEX_JSON.write('content', r.conteudo);
      APEX_JSON.close_object;
    END LOOP;

    -- Mensagem atual
    APEX_JSON.open_object;
    APEX_JSON.write('role',    'user');
    APEX_JSON.write('content', l_msg_clob);
    APEX_JSON.close_object;

    APEX_JSON.close_array;
    APEX_JSON.close_object;
    l_body := APEX_JSON.get_clob_output;
    APEX_JSON.free_output;

    -- Chama Claude API (Haiku: mais rápido e econômico, suficiente para o caso de uso)
    APEX_WEB_SERVICE.SET_REQUEST_HEADERS(
      p_name_01  => 'x-api-key',
      p_value_01 => pkg_gf_pierre.get_config('ANTHROPIC_API_KEY'),
      p_name_02  => 'anthropic-version',
      p_value_02 => '2023-06-01',
      p_name_03  => 'content-type',
      p_value_03 => 'application/json'
    );

    l_resp := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
      p_url         => 'https://api.anthropic.com/v1/messages',
      p_http_method => 'POST',
      p_body        => l_body
    );

    -- Extrai texto da resposta
    p_resposta := JSON_VALUE(l_resp, '$.content[0].text' RETURNING CLOB);

    IF p_resposta IS NULL THEN
      p_resposta := TO_CLOB('Erro ao processar resposta da IA. Raw: ' || SUBSTR(l_resp, 1, 500));
      RETURN;
    END IF;

    -- Salva no histórico
    INSERT INTO gf_chat_mensagem (role, conteudo) VALUES ('user',      p_mensagem);
    INSERT INTO gf_chat_mensagem (role, conteudo) VALUES ('assistant', p_resposta);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      APEX_JSON.free_output;
      ROLLBACK;
      p_resposta := TO_CLOB('Erro: ' || SQLERRM);
  END;

  PROCEDURE checkin(p_resposta OUT CLOB) IS
  BEGIN
    chat('Acabei de abrir o app. Faz o check-in financeiro.', p_resposta);
  END;

END pkg_gf_ai;
/
