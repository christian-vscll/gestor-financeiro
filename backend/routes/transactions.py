from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import inspect as sa_inspect
from typing import Optional
from pydantic import BaseModel
from database import get_db
from models import Transaction
from services.sync import sync_transactions

router = APIRouter(prefix="/api/transactions", tags=["transactions"])


def _to_dict(instance):
    return {c.key: getattr(instance, c.key) for c in sa_inspect(instance).mapper.column_attrs}


class ReviewUpdate(BaseModel):
    confirmed_category: str
    notes: Optional[str] = None


@router.post("/sync")
async def sync(db: Session = Depends(get_db)):
    try:
        return await sync_transactions(db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/pending")
def get_pending(db: Session = Depends(get_db)):
    txns = (
        db.query(Transaction)
        .filter(Transaction.review_status == "pending")
        .order_by(Transaction.date.desc())
        .all()
    )
    return [_to_dict(t) for t in txns]


@router.get("/")
def list_transactions(
    status: Optional[str] = None,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    q = db.query(Transaction)
    if status:
        q = q.filter(Transaction.review_status == status)
    return [_to_dict(t) for t in q.order_by(Transaction.date.desc()).limit(limit).all()]


@router.patch("/{txn_id}/review")
def review(txn_id: str, update: ReviewUpdate, db: Session = Depends(get_db)):
    t = db.query(Transaction).filter(Transaction.id == txn_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Not found")
    t.confirmed_category = update.confirmed_category
    t.notes = update.notes
    t.review_status = "confirmed"
    db.commit()
    return {"ok": True}


@router.patch("/{txn_id}/ignore")
def ignore(txn_id: str, db: Session = Depends(get_db)):
    t = db.query(Transaction).filter(Transaction.id == txn_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Not found")
    t.review_status = "ignored"
    db.commit()
    return {"ok": True}
