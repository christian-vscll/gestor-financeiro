from anthropic import Anthropic
from sqlalchemy.orm import Session
from sqlalchemy import inspect as sa_inspect
from models import Transaction, Debt, SinkingFund, ContextMemory, ChatMessage
from config import settings

client = Anthropic(api_key=settings.anthropic_api_key)

SYSTEM_PROMPT = """Você é o Finn, gerente financeiro pessoal do Christian.

## Perfil do Christian
- Dev PJ (Oracle APEX, PL/SQL, Python, OCI)
- Renda PJ: Contabilidade (4 pagamentos/mês, datas variadas) + clientes TI Scafom e Othon (2 pagamentos/mês)
- Cartões: Inter (vence dia 15), Nubank (vence dia 15), Leroy (vence dia 17)
- Esposa: Julia

## Dívidas em processo de quitação (venda da moto, R$ 17.000)
- Creditas (financiamento carro, alienação): ~R$ 9.120
- Mercado Pago empréstimo: ~R$ 3.200
- Nubank empréstimo: ~R$ 3.100
- 99Julia (em nome da Julia): ~18x R$ 600, a amortizar com margem liberada

## Recorrentes conhecidos
- Assinaturas: TotalPass, Netflix, YouTube Premium, Apple (múltiplas cobranças), Claude.ai, Google Workspace
- Seguros: Suhai, Zurich
- Pix recorrente: divisão viagem Búzios (6x R$ 475 — parcela compartilhada com amigos)
- Débito automático: plano de saúde da Julia

## Evento crítico próximo
- Oliver (1º filho) nasce agosto/2026 → novas despesas fixas (plano saúde bebê, fraldas) + únicas (enxoval, hospital)

## Seu papel como Finn
1. Categorizar transações com contexto real — vai além do que o Pierre sugere automaticamente
2. Identificar transações ambíguas e perguntar ao Christian (ex: "esse Pix de R$ 300 é reembolso da viagem ou despesa nova?")
3. Alertar sobre inconsistências, gastos incomuns e datas críticas de vencimento
4. Projetar fluxo de caixa e antecipar apertos
5. Lembrar contexto aprendido entre conversas e acumular conhecimento

## Estilo
- Direto, sem rodeios, em português brasileiro
- Proativo: não espera ser perguntado, avisa quando vê algo importante
- Sempre usa R$ nos valores
- Perguntas: no máximo 2 por vez para não sobrecarregar
- No check-in inicial: resume o que mudou + aponta o que precisa de atenção"""


def _build_context(db: Session) -> str:
    parts = []

    pending = (
        db.query(Transaction)
        .filter(Transaction.review_status == "pending")
        .order_by(Transaction.date.desc())
        .limit(30)
        .all()
    )
    if pending:
        parts.append(f"## Transações pendentes de revisão ({len(pending)})")
        for t in pending:
            sign = "+" if (t.amount or 0) > 0 else ""
            parts.append(
                f"- [{t.date}] {t.description} | {sign}R$ {t.amount:.2f} | "
                f"Pierre: {t.pierre_category} | {t.account_marketing_name}"
            )

    debts = db.query(Debt).filter(Debt.is_active == True).all()
    if debts:
        parts.append("\n## Dívidas ativas")
        for d in debts:
            parts.append(
                f"- {d.name}: R$ {d.remaining_amount:.2f} restantes | "
                f"R$ {d.monthly_payment:.2f}/mês | vence dia {d.due_day}"
            )

    funds = db.query(SinkingFund).all()
    if funds:
        parts.append("\n## Reservas (sinking funds)")
        for f in funds:
            parts.append(
                f"- {f.name}: R$ {f.current_amount:.2f} acumulado / "
                f"R$ {f.target_amount:.2f} meta (+R$ {f.monthly_contribution:.2f}/mês)"
            )

    memories = db.query(ContextMemory).all()
    if memories:
        parts.append("\n## Contexto aprendido")
        for m in memories:
            parts.append(f"- {m.key}: {m.description}")

    return "\n".join(parts)


async def chat(user_message: str, db: Session) -> str:
    context = _build_context(db)

    history = (
        db.query(ChatMessage)
        .order_by(ChatMessage.created_at.desc())
        .limit(20)
        .all()
    )
    history.reverse()

    messages = [{"role": m.role, "content": m.content} for m in history]

    full_msg = user_message
    if context:
        full_msg = f"{user_message}\n\n---\n[Dados do sistema]\n{context}"

    messages.append({"role": "user", "content": full_msg})

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        system=SYSTEM_PROMPT,
        messages=messages,
    )

    reply = response.content[0].text

    db.add(ChatMessage(role="user", content=user_message))
    db.add(ChatMessage(role="assistant", content=reply))
    db.commit()

    return reply


async def checkin(db: Session) -> str:
    return await chat(
        "Acabei de abrir o app. Faz o check-in financeiro.",
        db,
    )
