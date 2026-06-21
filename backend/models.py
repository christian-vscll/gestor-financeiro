from sqlalchemy import Column, String, Float, Date, DateTime, Boolean, Integer, Text, func
from database import Base


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String, primary_key=True)
    description = Column(String)
    pierre_category = Column(String)
    confirmed_category = Column(String)
    amount = Column(Float)
    balance = Column(Float)
    date = Column(Date)
    type = Column(String)
    status = Column(String)
    account_name = Column(String)
    account_type = Column(String)
    account_subtype = Column(String)
    account_marketing_name = Column(String)
    review_status = Column(String, default="pending")
    notes = Column(Text)
    created_at = Column(DateTime, server_default=func.now())


class SyncLog(Base):
    __tablename__ = "sync_log"

    id = Column(Integer, primary_key=True, autoincrement=True)
    synced_at = Column(DateTime, server_default=func.now())
    transactions_fetched = Column(Integer, default=0)
    transactions_new = Column(Integer, default=0)


class Debt(Base):
    __tablename__ = "debts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    total_amount = Column(Float)
    remaining_amount = Column(Float)
    monthly_payment = Column(Float)
    due_day = Column(Integer)
    installments_remaining = Column(Integer)
    notes = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())


class SinkingFund(Base):
    __tablename__ = "sinking_funds"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    target_amount = Column(Float)
    monthly_contribution = Column(Float)
    current_amount = Column(Float, default=0)
    target_date = Column(Date)
    notes = Column(Text)
    created_at = Column(DateTime, server_default=func.now())


class CashFlowEvent(Base):
    __tablename__ = "cash_flow_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    description = Column(String, nullable=False)
    amount = Column(Float)
    expected_date = Column(Date)
    recurrence = Column(String)
    category = Column(String)
    is_confirmed = Column(Boolean, default=False)
    notes = Column(Text)


class ContextMemory(Base):
    __tablename__ = "context_memory"

    id = Column(Integer, primary_key=True, autoincrement=True)
    key = Column(String, unique=True, nullable=False)
    description = Column(String)
    value = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    role = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
