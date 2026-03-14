from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, List
from firebase_admin import firestore
import uuid

router = APIRouter()
db = firestore.client()

class QuestTemplateCreate(BaseModel):
    title: str
    description: str
    category: str
    difficulty: str
    estimatedMinutes: int
    baseCoins: int
    proofType: str

class QuestInstanceCreate(BaseModel):
    questTemplateId: str
    childId: str

class QuestInstanceUpdate(BaseModel):
    status: str
    proofData: Optional[str] = None

@router.get("/templates")
def get_quest_templates():
    docs = db.collection('QuestTemplates').stream()
    return [{"id": doc.id, **doc.to_dict()} for doc in docs]

@router.post("/templates")
def create_quest_template(quest: QuestTemplateCreate):
    doc_ref = db.collection('QuestTemplates').document(str(uuid.uuid4()))
    doc_ref.set(quest.dict())
    return {"id": doc_ref.id, **quest.dict()}

@router.get("/instances/{child_id}")
def get_quest_instances(child_id: str):
    docs = db.collection('QuestInstances').where('childId', '==', child_id).stream()
    return [{"id": doc.id, **doc.to_dict()} for doc in docs]

@router.post("/instances")
def start_quest(instance: QuestInstanceCreate):
    doc_ref = db.collection('QuestInstances').document(str(uuid.uuid4()))
    data = instance.dict()
    data['status'] = 'in-progress'
    data['earnedCoins'] = 0
    doc_ref.set(data)
    return {"id": doc_ref.id, **data}

@router.patch("/instances/{instance_id}")
def update_quest_status(instance_id: str, update: QuestInstanceUpdate):
    doc_ref = db.collection('QuestInstances').document(instance_id)
    doc_ref.update(update.dict(exclude_unset=True))

    if update.status == 'approved':
        instance = doc_ref.get().to_dict()
        template = db.collection('QuestTemplates').document(instance['questTemplateId']).get().to_dict()
        wallet_ref = db.collection('Wallets').document(instance['childId'])
        wallet = wallet_ref.get().to_dict()
        new_balance = wallet.get('balanceCoins', 0) + template.get('baseCoins', 0)
        wallet_ref.set({"balanceCoins": new_balance}, merge=True)
        doc_ref.update({"earnedCoins": template.get('baseCoins', 0)})

    return {"message": "Status updated successfully"}
