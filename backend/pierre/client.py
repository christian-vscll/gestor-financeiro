import httpx
from datetime import date
from typing import Optional
from config import settings

BASE_URL = "https://www.pierre.finance/tools/api"


class PierreClient:
    def __init__(self):
        self.headers = {"Authorization": f"Bearer {settings.pierre_api_key}"}

    async def _get(self, path: str, params: dict = None):
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.get(f"{BASE_URL}/{path}", headers=self.headers, params=params)
            r.raise_for_status()
            return r.json()

    async def _post(self, path: str, json: dict = None):
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.post(f"{BASE_URL}/{path}", headers=self.headers, json=json or {})
            r.raise_for_status()
            return r.json()

    async def get_accounts(self):
        return await self._get("get-accounts")

    async def get_balance(self):
        return await self._get("get-balance")

    async def get_bill_summary(self):
        return await self._get("get-bill-summary")

    async def get_bills(self):
        return await self._get("get-bills")

    async def get_installments(self):
        return await self._get("get-installments")

    async def get_memories(self):
        return await self._get("get-memories")

    async def get_expensive_categories(self):
        return await self._get("get-expensive-categories")

    async def get_transactions(
        self,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        account_type: Optional[str] = None,
        categories: Optional[str] = None,
        format: str = "raw",
    ):
        params: dict = {"format": format}
        if start_date:
            params["startDate"] = start_date.isoformat()
        if end_date:
            params["endDate"] = end_date.isoformat()
        if account_type:
            params["accountType"] = account_type
        if categories:
            params["categories"] = categories
        return await self._get("get-transactions", params)

    async def manual_update(self):
        return await self._post("manual-update")


pierre = PierreClient()
