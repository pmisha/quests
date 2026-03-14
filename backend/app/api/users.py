from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from firebase_admin import firestore
import uuid

router = APIRouter()
db = firestore.client()

class UserCreate(BaseModel):
    name: str
    role: str
    age: Optional[int] = None
    parentId: Optional[str] = None

@router.get("/")
def get_users():
    docs = db.collection('Users').stream()
    return [{"id": doc.id, **doc.to_dict()} for doc in docs]

@router.post("/")
def create_user(user: UserCreate):
    doc_ref = db.collection('Users').document(str(uuid.uuid4()))
    doc_ref.set(user.dict(exclude_none=True))
    if user.role == "child":
        db.collection('Wallets').document(doc_ref.id).set({"balanceCoins": 0, "totalLifetimeCoins": 0})
    return {"id": doc_ref.id, **user.dict(exclude_none=True)}

@router.get("/{user_id}/wallet")
def get_wallet(user_id: str):
    doc = db.collection('Wallets').document(user_id).get()
    if not doc.exists:
        return {"balanceCoins": 0, "totalLifetimeCoins": 0}
    return doc.to_dict()
