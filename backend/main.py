from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine
import models
from routes.transactions import router as transactions_router
from routes.chat import router as chat_router
from routes.accounts import router as accounts_router

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Gestor Financeiro Pessoal")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(transactions_router)
app.include_router(chat_router)
app.include_router(accounts_router)


@app.get("/health")
def health():
    return {"status": "ok"}
