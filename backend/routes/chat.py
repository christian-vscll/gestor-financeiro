from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from database import get_db
from models import ChatMessage
from services.ai import chat, checkin

router = APIRouter(prefix="/api/chat", tags=["chat"])


class ChatRequest(BaseModel):
    message: str


@router.post("/")
async def send_message(req: ChatRequest, db: Session = Depends(get_db)):
    reply = await chat(req.message, db)
    return {"response": reply}


@router.get("/checkin")
async def do_checkin(db: Session = Depends(get_db)):
    reply = await checkin(db)
    return {"response": reply}


@router.delete("/history")
def clear_history(db: Session = Depends(get_db)):
    db.query(ChatMessage).delete()
    db.commit()
    return {"ok": True}
