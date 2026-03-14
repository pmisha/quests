from fastapi import APIRouter
from pydantic import BaseModel
from firebase_admin import firestore
import uuid

router = APIRouter()
db = firestore.client()

class RewardCreate(BaseModel):
    title: str
    description: str
    imageUrl: str
    coinCost: int
    type: str
    active: bool = True

class RedemptionCreate(BaseModel):
    rewardId: str
    childId: str

@router.get("/")
def get_rewards():
    docs = db.collection('Rewards').where('active', '==', True).stream()
    return [{"id": doc.id, **doc.to_dict()} for doc in docs]

@router.post("/")
def create_reward(reward: RewardCreate):
    doc_ref = db.collection('Rewards').document(str(uuid.uuid4()))
    doc_ref.set(reward.dict())
    return {"id": doc_ref.id, **reward.dict()}

@router.post("/redeem")
def request_redemption(redemption: RedemptionCreate):
    reward = db.collection('Rewards').document(redemption.rewardId).get().to_dict()
    wallet_ref = db.collection('Wallets').document(redemption.childId)
    wallet = wallet_ref.get().to_dict()

    if wallet.get('balanceCoins', 0) < reward.get('coinCost', 0):
        return {"error": "Insufficient balance"}

    new_balance = wallet.get('balanceCoins', 0) - reward.get('coinCost', 0)
    wallet_ref.set({"balanceCoins": new_balance}, merge=True)

    doc_ref = db.collection('Redemptions').document(str(uuid.uuid4()))
    data = redemption.dict()
    data['status'] = 'requested'
    doc_ref.set(data)

    return {"id": doc_ref.id, **data}
