from fastapi import APIRouter, HTTPException
from pierre.client import pierre

router = APIRouter(prefix="/api/accounts", tags=["accounts"])


@router.get("/")
async def accounts():
    try:
        return await pierre.get_accounts()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/balance")
async def balance():
    try:
        return await pierre.get_balance()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/bills")
async def bills():
    try:
        return await pierre.get_bills()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/bill-summary")
async def bill_summary():
    try:
        return await pierre.get_bill_summary()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
