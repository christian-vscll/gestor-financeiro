from datetime import date, timedelta
from sqlalchemy.orm import Session
from models import Transaction, SyncLog
from pierre.client import pierre


async def sync_transactions(db: Session) -> dict:
    last_sync = db.query(SyncLog).order_by(SyncLog.synced_at.desc()).first()

    if last_sync:
        # 1-day overlap to catch late-posted transactions
        start_date = last_sync.synced_at.date() - timedelta(days=1)
    else:
        start_date = date.today() - timedelta(days=90)

    end_date = date.today()

    result = await pierre.get_transactions(start_date=start_date, end_date=end_date)

    if not result.get("success"):
        raise Exception(f"Pierre API error: {result}")

    raw = result.get("data", [])
    new_count = 0

    for t in raw:
        existing = db.query(Transaction).filter(Transaction.id == t["id"]).first()
        if not existing:
            txn = Transaction(
                id=t["id"],
                description=t.get("description"),
                pierre_category=t.get("category"),
                amount=t.get("amount"),
                balance=t.get("balance"),
                date=date.fromisoformat(t["date"]) if t.get("date") else None,
                type=t.get("type"),
                status=t.get("status"),
                account_name=t.get("account_name"),
                account_type=t.get("account_type"),
                account_subtype=t.get("account_subtype"),
                account_marketing_name=t.get("account_marketing_name"),
                review_status="pending",
            )
            db.add(txn)
            new_count += 1

    db.add(SyncLog(transactions_fetched=len(raw), transactions_new=new_count))
    db.commit()

    return {
        "fetched": len(raw),
        "new": new_count,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
    }
