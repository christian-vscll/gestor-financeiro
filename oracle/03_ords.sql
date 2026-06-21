-- =============================================================
-- ORDS - Templates e Handlers
-- Módulo 'gestor-financeiro' já criado manualmente
-- Base: /ords/dev_3aconsult/gestor-financeiro/
--
-- ATENÇÃO: Habilite CORS no módulo pelo APEX Builder ou:
--   ORDS.SET_MODULE_ORIGINS_ALLOWED('gestor-financeiro','*');
-- =============================================================

-- Limpa templates existentes para recriar limpo
DECLARE
  PROCEDURE del(p_tpl VARCHAR2) IS
  BEGIN
    ORDS.DELETE_TEMPLATE('gestor-financeiro', p_tpl);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  del('transacoes/');
  del('transacoes/pendentes/');
  del('transacoes/sync/');
  del('transacoes/:id/revisar/');
  del('transacoes/:id/ignorar/');
  del('chat/');
  del('chat/checkin/');
  del('chat/historico/');
  del('contas/saldo/');
  del('contas/faturas/');
  del('config/');
END;
/

BEGIN

  -- ===========================================================
  -- TRANSAÇÕES
  -- ===========================================================

  -- GET /transacoes/ — lista com filtro opcional de status
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'transacoes/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'transacoes/',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_query,
    p_source      =>
      'SELECT id,
              descricao,
              categoria_pierre,
              categoria_confirmada,
              valor,
              saldo,
              TO_CHAR(data_transacao, ''YYYY-MM-DD'') data_transacao,
              tipo,
              status,
              conta_nome_marketing,
              conta_nome,
              conta_tipo,
              status_revisao,
              notas,
              TO_CHAR(criado_em, ''YYYY-MM-DD"T"HH24:MI:SS'') criado_em
         FROM gf_transacao
        WHERE (:status IS NULL OR status_revisao = :status)
        ORDER BY data_transacao DESC
        FETCH FIRST NVL(:limite, 50) ROWS ONLY'
  );

  -- GET /transacoes/pendentes/ — somente pendentes (usado pela fila de revisão)
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'transacoes/pendentes/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'transacoes/pendentes/',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_query,
    p_source      =>
      'SELECT id,
              descricao,
              categoria_pierre,
              valor,
              saldo,
              TO_CHAR(data_transacao, ''YYYY-MM-DD'') data_transacao,
              tipo,
              status,
              conta_nome_marketing,
              conta_nome,
              conta_tipo,
              status_revisao
         FROM gf_transacao
        WHERE status_revisao = ''pending''
        ORDER BY data_transacao DESC'
  );

  -- POST /transacoes/sync/ — sincroniza transações novas do Pierre
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'transacoes/sync/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'transacoes/sync/',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'DECLARE
         l_resultado CLOB;
         l_pos       NUMBER := 1;
       BEGIN
         pkg_gf_pierre.sync_transacoes(l_resultado);
         OWA_UTIL.MIME_HEADER(''application/json'', FALSE);
         OWA_UTIL.HTTP_HEADER_CLOSE;
         WHILE l_pos <= DBMS_LOB.GETLENGTH(l_resultado) LOOP
           HTP.P(DBMS_LOB.SUBSTR(l_resultado, 32000, l_pos));
           l_pos := l_pos + 32000;
         END LOOP;
         :status_code := 200;
       END;'
  );

  -- POST /transacoes/:id/revisar/ — confirma categoria de uma transação
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'transacoes/:id/revisar/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'transacoes/:id/revisar/',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'BEGIN
         UPDATE gf_transacao
            SET categoria_confirmada = :categoria_confirmada,
                notas                = :notas,
                status_revisao       = ''confirmed''
          WHERE id = :id;
         COMMIT;
         :status_code := 200;
       END;'
  );

  -- POST /transacoes/:id/ignorar/ — marca transação como ignorada
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'transacoes/:id/ignorar/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'transacoes/:id/ignorar/',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'BEGIN
         UPDATE gf_transacao
            SET status_revisao = ''ignored''
          WHERE id = :id;
         COMMIT;
         :status_code := 200;
       END;'
  );

  -- ===========================================================
  -- CHAT (Finn)
  -- ===========================================================

  -- POST /chat/ — envia mensagem para o Finn (chama Claude API)
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'chat/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'chat/',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'DECLARE
         l_resposta CLOB;
         l_json     CLOB;
         l_pos      NUMBER := 1;
       BEGIN
         pkg_gf_ai.chat(:message, l_resposta);
         APEX_JSON.initialize_clob_output;
         APEX_JSON.open_object;
         APEX_JSON.write(''response'', l_resposta);
         APEX_JSON.close_object;
         l_json := APEX_JSON.get_clob_output;
         APEX_JSON.free_output;
         OWA_UTIL.MIME_HEADER(''application/json'', FALSE);
         OWA_UTIL.HTTP_HEADER_CLOSE;
         WHILE l_pos <= DBMS_LOB.GETLENGTH(l_json) LOOP
           HTP.P(DBMS_LOB.SUBSTR(l_json, 32000, l_pos));
           l_pos := l_pos + 32000;
         END LOOP;
         :status_code := 200;
       END;'
  );

  -- GET /chat/checkin/ — check-in automático ao abrir o app
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'chat/checkin/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'chat/checkin/',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'DECLARE
         l_resposta CLOB;
         l_json     CLOB;
         l_pos      NUMBER := 1;
       BEGIN
         pkg_gf_ai.checkin(l_resposta);
         APEX_JSON.initialize_clob_output;
         APEX_JSON.open_object;
         APEX_JSON.write(''response'', l_resposta);
         APEX_JSON.close_object;
         l_json := APEX_JSON.get_clob_output;
         APEX_JSON.free_output;
         OWA_UTIL.MIME_HEADER(''application/json'', FALSE);
         OWA_UTIL.HTTP_HEADER_CLOSE;
         WHILE l_pos <= DBMS_LOB.GETLENGTH(l_json) LOOP
           HTP.P(DBMS_LOB.SUBSTR(l_json, 32000, l_pos));
           l_pos := l_pos + 32000;
         END LOOP;
         :status_code := 200;
       END;'
  );

  -- DELETE /chat/historico/ — limpa histórico da conversa
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'chat/historico/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'chat/historico/',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_query,
    p_source      =>
      'SELECT role,
              conteudo,
              TO_CHAR(criado_em, ''YYYY-MM-DD"T"HH24:MI:SS'') criado_em
         FROM gf_chat_mensagem
        ORDER BY criado_em ASC
        FETCH FIRST 100 ROWS ONLY'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'chat/historico/',
    p_method      => 'DELETE',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'BEGIN
         DELETE FROM gf_chat_mensagem;
         COMMIT;
         :status_code := 200;
       END;'
  );

  -- ===========================================================
  -- CONTAS (passthrough direto para Pierre)
  -- ===========================================================

  -- GET /contas/saldo/
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'contas/saldo/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'contas/saldo/',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'DECLARE
         l_resp CLOB;
         l_pos  NUMBER := 1;
       BEGIN
         l_resp := pkg_gf_pierre.get_saldo;
         OWA_UTIL.MIME_HEADER(''application/json'', FALSE);
         OWA_UTIL.HTTP_HEADER_CLOSE;
         WHILE l_pos <= DBMS_LOB.GETLENGTH(l_resp) LOOP
           HTP.P(DBMS_LOB.SUBSTR(l_resp, 32000, l_pos));
           l_pos := l_pos + 32000;
         END LOOP;
         :status_code := 200;
       END;'
  );

  -- GET /contas/faturas/
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'contas/faturas/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'contas/faturas/',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'DECLARE
         l_resp CLOB;
         l_pos  NUMBER := 1;
       BEGIN
         l_resp := pkg_gf_pierre.get_faturas;
         OWA_UTIL.MIME_HEADER(''application/json'', FALSE);
         OWA_UTIL.HTTP_HEADER_CLOSE;
         WHILE l_pos <= DBMS_LOB.GETLENGTH(l_resp) LOOP
           HTP.P(DBMS_LOB.SUBSTR(l_resp, 32000, l_pos));
           l_pos := l_pos + 32000;
         END LOOP;
         :status_code := 200;
       END;'
  );

  -- ===========================================================
  -- CONFIG — upsert de chave/valor (para atualizar API keys)
  -- ===========================================================
  ORDS.DEFINE_TEMPLATE('gestor-financeiro', 'config/');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'gestor-financeiro',
    p_pattern     => 'config/',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      =>
      'BEGIN
         MERGE INTO gf_config dst
         USING (SELECT :chave chave, :valor valor FROM dual) src
         ON (dst.chave = src.chave)
         WHEN MATCHED     THEN UPDATE SET dst.valor = src.valor
         WHEN NOT MATCHED THEN INSERT (chave, valor) VALUES (src.chave, src.valor);
         COMMIT;
         :status_code := 200;
       END;'
  );

  COMMIT;
END;
/

-- Habilita CORS para o módulo (necessário para o frontend chamar de outro domínio)
-- ATENÇÃO: '*' NÃO funciona como wildcard no ORDS — use a URL exata do frontend
BEGIN
  ORDS.SET_MODULE_ORIGINS_ALLOWED(
    p_module_name     => 'gestor-financeiro',
    p_origins_allowed => 'https://gestor-financeiro-coral.vercel.app'
  );
  COMMIT;
END;
/
