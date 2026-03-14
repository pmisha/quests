#!/bin/bash

echo "Starting Regeneration..."

# 1. Base files
cat << 'INNER_EOF' > .gitignore
node_modules/
backend/venv/
__pycache__/
*.pyc
.env
firebase-debug.log
ui-debug.log
.DS_Store
dist/
build/
.firebase/
mock-cred.json
INNER_EOF

cat << 'INNER_EOF' > start.sh
#!/bin/bash
pkill -f "uvicorn" || true
pkill -f "vite" || true
pkill -f "firebase" || true
sleep 2

firebase emulators:start --project demo-general-quests-store > firebase_emulator.log 2>&1 &

cd backend
source venv/bin/activate
export GOOGLE_APPLICATION_CREDENTIALS=""
uvicorn app.main:app --host 0.0.0.0 --port 8000 > backend.log 2>&1 &
cd ..

cd frontend
npm run dev > frontend.log 2>&1 &
cd ..

echo "All services started! (wait 5s for ports to open)"
INNER_EOF
chmod +x start.sh

# 2. Firebase config
cat << 'INNER_EOF' > firebase.json
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 },
    "singleProjectMode": true
  }
}
INNER_EOF

cat << 'INNER_EOF' > .firebaserc
{ "projects": { "default": "demo-general-quests-store" } }
INNER_EOF

# 3. Backend (FastAPI)
mkdir -p backend/app/api
cat << 'INNER_EOF' > backend/requirements.txt
fastapi
uvicorn
firebase-admin
pydantic
python-dotenv
INNER_EOF
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -r backend/requirements.txt

cat << 'INNER_EOF' > backend/app/__init__.py
INNER_EOF
cat << 'INNER_EOF' > backend/app/api/__init__.py
INNER_EOF

cat << 'INNER_EOF' > backend/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials
import os

os.environ["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:8080"
os.environ["FIREBASE_AUTH_EMULATOR_HOST"] = "127.0.0.1:9099"

if not firebase_admin._apps:
    try:
        from google.auth.credentials import AnonymousCredentials
        class MockCredential(credentials.Base):
            def get_credential(self):
                return AnonymousCredentials()
        firebase_admin.initialize_app(MockCredential(), options={'projectId': 'demo-general-quests-store'})
    except Exception as e:
        print("Error initializing app:", e)

app = FastAPI(title="General Quests Store MVP")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from .api import quests, rewards, users

app.include_router(quests.router, prefix="/api/quests", tags=["quests"])
app.include_router(rewards.router, prefix="/api/rewards", tags=["rewards"])
app.include_router(users.router, prefix="/api/users", tags=["users"])

@app.get("/")
def read_root():
    return {"message": "Welcome to General Quests Store API"}
INNER_EOF

cat << 'INNER_EOF' > backend/app/api/quests.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/app/api/rewards.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/app/api/users.py
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
INNER_EOF

# 4. Frontend (React + Vite + Tailwind)
if [ ! -d "frontend" ]; then
    npx create-vite frontend --template react
fi
cd frontend
npm install
npm install -D tailwindcss@3 postcss autoprefixer
npx tailwindcss init -p
npm install react-router-dom firebase

cat << 'INNER_EOF' > tailwind.config.js
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: { extend: {} },
  plugins: [],
}
INNER_EOF

cat << 'INNER_EOF' > src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;
INNER_EOF

cat << 'INNER_EOF' > vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
export default defineConfig({ plugins: [react()], server: { port: 3000 } })
INNER_EOF

cat << 'INNER_EOF' > src/firebase.js
import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';

const firebaseConfig = {
  projectId: 'demo-general-quests-store',
  apiKey: 'fake-api-key',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
}
INNER_EOF

mkdir -p src/contexts src/pages

cat << 'INNER_EOF' > src/contexts/AuthContext.jsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, getDocs } from 'firebase/firestore';

const AuthContext = createContext();
export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [currentUser, setCurrentUser] = useState(null);

  const login = async (role) => {
    try {
      const usersRef = collection(db, 'Users');
      const querySnapshot = await getDocs(usersRef);
      const userDoc = querySnapshot.docs.find(doc => doc.data().role === role);

      if (userDoc) {
        setCurrentUser({ id: userDoc.id, ...userDoc.data() });
      } else {
        const response = await fetch('http://localhost:8000/api/users', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: role === 'child' ? 'Kid' : 'Parent', role })
        });
        const newUser = await response.json();
        setCurrentUser(newUser);
      }
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <AuthContext.Provider value={{ currentUser, login, logout: () => setCurrentUser(null) }}>
      {children}
    </AuthContext.Provider>
  );
};
INNER_EOF

cat << 'INNER_EOF' > src/pages/Login.jsx
import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);

  const handleLogin = async (role) => {
    setLoading(true);
    await login(role);
    setLoading(false);
    navigate('/');
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      <div className="p-8 bg-white shadow-lg rounded-xl max-w-sm w-full text-center">
        <h1 className="text-2xl font-bold mb-6 text-indigo-600">General Quests Store</h1>
        <p className="mb-4 text-gray-600">Select your role to enter:</p>
        <button disabled={loading} onClick={() => handleLogin('parent')} className="w-full bg-blue-500 text-white font-semibold py-2 px-4 rounded-lg mb-4 hover:bg-blue-600 transition">Login as Parent</button>
        <button disabled={loading} onClick={() => handleLogin('child')} className="w-full bg-green-500 text-white font-semibold py-2 px-4 rounded-lg hover:bg-green-600 transition">Login as Kid</button>
      </div>
    </div>
  );
}
INNER_EOF

cat << 'INNER_EOF' > src/pages/Home.jsx
import React from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Home() {
  const { currentUser, logout } = useAuth();
  const navigate = useNavigate();

  if (currentUser?.role === 'parent') {
    return (
      <div className="p-4 bg-gray-50 min-h-screen">
        <header className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Parent Dashboard</h1>
          <button onClick={() => { logout(); navigate('/login'); }} className="text-red-500 font-semibold">Logout</button>
        </header>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="bg-white p-6 rounded-xl shadow cursor-pointer hover:bg-gray-50 transition" onClick={() => navigate('/parent/quests')}>
            <h2 className="text-xl font-semibold text-blue-600">Manage Quests</h2>
            <p className="text-gray-600 text-sm mt-1">Create and edit quest templates.</p>
          </div>
          <div className="bg-white p-6 rounded-xl shadow cursor-pointer hover:bg-gray-50 transition" onClick={() => navigate('/parent/store')}>
            <h2 className="text-xl font-semibold text-green-600">Manage Rewards</h2>
            <p className="text-gray-600 text-sm mt-1">Add or edit items in the store.</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 bg-gradient-to-br from-indigo-50 to-blue-100 min-h-screen">
      <header className="flex justify-between items-center mb-6 p-4 bg-white rounded-2xl shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-indigo-500 rounded-full flex items-center justify-center text-white font-bold text-xl">{currentUser?.name?.charAt(0) || 'K'}</div>
          <div><h1 className="text-xl font-bold">Hi, {currentUser?.name}!</h1><p className="text-sm font-semibold text-yellow-500">⭐ Level 1</p></div>
        </div>
      </header>
      <div className="grid grid-cols-2 gap-4 mb-6">
        <button onClick={() => navigate('/kid/quests')} className="bg-white p-6 rounded-3xl shadow-sm hover:shadow-md transition text-center flex flex-col items-center gap-2 group">
          <div className="w-16 h-16 bg-blue-100 rounded-2xl flex items-center justify-center text-3xl group-hover:scale-110 transition-transform">🎯</div>
          <span className="font-bold text-gray-700">Find Quests</span>
        </button>
        <button onClick={() => navigate('/kid/store')} className="bg-white p-6 rounded-3xl shadow-sm hover:shadow-md transition text-center flex flex-col items-center gap-2 group">
          <div className="w-16 h-16 bg-purple-100 rounded-2xl flex items-center justify-center text-3xl group-hover:scale-110 transition-transform">🛍️</div>
          <span className="font-bold text-gray-700">Reward Store</span>
        </button>
      </div>
      <button onClick={() => { logout(); navigate('/login'); }} className="mt-8 text-red-400 hover:text-red-600 font-semibold w-full text-center">Logout</button>
    </div>
  );
}
INNER_EOF

cat << 'INNER_EOF' > src/pages/QuestList.jsx
import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function QuestList() {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const [quests, setQuests] = useState([]);

  useEffect(() => {
    fetch('http://localhost:8000/api/quests/templates')
      .then(r => r.json())
      .then(setQuests)
      .catch(console.error);
  }, []);

  const handleCreateQuest = async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const newQuest = {
      title: formData.get('title'),
      description: formData.get('description'),
      category: formData.get('category'),
      difficulty: formData.get('difficulty'),
      estimatedMinutes: parseInt(formData.get('estimatedMinutes')),
      baseCoins: parseInt(formData.get('baseCoins')),
      proofType: formData.get('proofType')
    };

    try {
      const response = await fetch('http://localhost:8000/api/quests/templates', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newQuest)
      });
      if (response.ok) {
        const createdQuest = await response.json();
        setQuests([...quests, createdQuest]);
        e.target.reset();
      }
    } catch (error) {
      console.error(error);
    }
  };

  const handleStartQuest = async (questId) => {
    try {
      const response = await fetch('http://localhost:8000/api/quests/instances', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ questTemplateId: questId, childId: currentUser.id })
      });
      if (response.ok) {
        alert("Quest started successfully!");
      }
    } catch (error) {
      console.error(error);
    }
  };

  if (currentUser?.role === 'parent') {
    return (
      <div className="p-4 bg-gray-50 min-h-screen">
        <header className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Manage Quests</h1>
          <button onClick={() => navigate('/')} className="text-blue-500 font-semibold hover:underline">Back</button>
        </header>

        <div className="bg-white p-6 rounded-xl shadow mb-8">
          <h2 className="text-xl font-bold mb-4">Create New Quest</h2>
          <form onSubmit={handleCreateQuest} className="space-y-4">
            <input name="title" placeholder="Quest Title" className="w-full border p-2 rounded" required />
            <textarea name="description" placeholder="Description" className="w-full border p-2 rounded" required></textarea>
            <div className="grid grid-cols-2 gap-4">
              <select name="category" className="border p-2 rounded" required>
                <option value="Academic">Academic</option>
                <option value="Life/Finance">Life/Finance</option>
                <option value="Creativity">Creativity</option>
                <option value="Family/Responsibility">Family/Responsibility</option>
              </select>
              <select name="difficulty" className="border p-2 rounded" required>
                <option value="Easy">Easy</option><option value="Medium">Medium</option><option value="Hard">Hard</option>
              </select>
              <input name="estimatedMinutes" type="number" placeholder="Estimated Minutes" className="border p-2 rounded" required />
              <input name="baseCoins" type="number" placeholder="Base Coins Reward" className="border p-2 rounded" required />
              <select name="proofType" className="border p-2 rounded col-span-2" required>
                <option value="None">No Proof Required</option>
                <option value="Text">Text Answer</option>
                <option value="Photo">Photo Upload</option>
              </select>
            </div>
            <button type="submit" className="w-full bg-blue-500 text-white font-bold py-2 rounded">Create Quest</button>
          </form>
        </div>

        <div className="bg-white p-6 rounded-xl shadow">
          <h2 className="text-xl font-bold mb-4">Existing Quests</h2>
          <div className="space-y-4">
            {quests.length === 0 ? <p className="text-gray-500">No quests created yet.</p> : quests.map(q => (
              <div key={q.id} className="border p-4 rounded-lg flex justify-between items-center">
                <div>
                  <h3 className="font-bold text-lg">{q.title}</h3>
                  <div className="flex gap-2 mt-1">
                    <span className="text-xs bg-gray-200 px-2 py-1 rounded">{q.category}</span>
                    <span className="text-xs bg-yellow-100 px-2 py-1 rounded text-yellow-800">🪙 {q.baseCoins}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 bg-gradient-to-br from-indigo-50 to-blue-100 min-h-screen pb-20">
      <header className="flex justify-between items-center mb-6 pt-2">
        <h1 className="text-3xl font-black text-gray-800">Quests</h1>
        <button onClick={() => navigate('/')} className="w-10 h-10 bg-white rounded-full flex items-center justify-center font-bold text-gray-500">✕</button>
      </header>
      <div className="space-y-4">
        {quests.length === 0 ? (
          <div className="text-center p-8 bg-white rounded-3xl shadow-sm text-gray-400 font-medium">No quests available!</div>
        ) : quests.map(quest => (
          <div key={quest.id} className="bg-white p-5 rounded-3xl shadow-sm">
            <div className="flex justify-between items-start mb-2">
              <span className="text-xs font-bold uppercase text-indigo-500 bg-indigo-50 px-2 py-1 rounded-lg">{quest.category}</span>
              <div className="flex items-center gap-1 bg-yellow-100 text-yellow-700 px-3 py-1 rounded-full font-bold text-sm">🪙 {quest.baseCoins}</div>
            </div>
            <h3 className="font-bold text-xl text-gray-800 mb-1">{quest.title}</h3>
            <p className="text-sm text-gray-500 mb-4">{quest.description}</p>
            <div className="flex justify-between items-center">
              <div className="text-xs font-bold text-gray-400">{quest.estimatedMinutes} mins</div>
              <button onClick={() => handleStartQuest(quest.id)} className="px-5 py-2 bg-indigo-500 text-white font-bold rounded-xl text-sm">Start</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
INNER_EOF

cat << 'INNER_EOF' > src/pages/Store.jsx
import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Store() {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const [rewards, setRewards] = useState([]);
  const [wallet, setWallet] = useState({ balanceCoins: 0 });

  useEffect(() => {
    fetch('http://localhost:8000/api/rewards')
      .then(r => r.json())
      .then(setRewards)
      .catch(console.error);

    if (currentUser?.role === 'child') {
      fetch(`http://localhost:8000/api/users/${currentUser.id}/wallet`)
        .then(r => r.json())
        .then(setWallet)
        .catch(console.error);
    }
  }, [currentUser]);

  const handleCreateReward = async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const newReward = {
      title: formData.get('title'),
      description: formData.get('description'),
      imageUrl: formData.get('imageUrl') || 'https://via.placeholder.com/150',
      coinCost: parseInt(formData.get('coinCost')),
      type: formData.get('type')
    };

    try {
      const response = await fetch('http://localhost:8000/api/rewards', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newReward)
      });
      if (response.ok) {
        setRewards([...rewards, await response.json()]);
        e.target.reset();
      }
    } catch (error) {
      console.error(error);
    }
  };

  const handleRedeem = async (rewardId) => {
    try {
      const response = await fetch('http://localhost:8000/api/rewards/redeem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rewardId, childId: currentUser.id })
      });
      if (response.ok) {
        alert("Redemption requested successfully!");
        const newWallet = await fetch(`http://localhost:8000/api/users/${currentUser.id}/wallet`).then(res => res.json());
        setWallet(newWallet);
      } else {
        alert("Failed to redeem. Do you have enough coins?");
      }
    } catch (error) {
      console.error(error);
    }
  };

  if (currentUser?.role === 'parent') {
    return (
      <div className="p-4 bg-gray-50 min-h-screen">
        <header className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Manage Store</h1>
          <button onClick={() => navigate('/')} className="text-green-600 font-semibold hover:underline">Back</button>
        </header>

        <div className="bg-white p-6 rounded-xl shadow mb-8">
          <h2 className="text-xl font-bold mb-4">Add New Reward</h2>
          <form onSubmit={handleCreateReward} className="space-y-4">
            <input name="title" placeholder="Reward Name" className="w-full border p-2 rounded" required />
            <input name="description" placeholder="Description" className="w-full border p-2 rounded" required />
            <div className="grid grid-cols-2 gap-4">
              <input name="coinCost" type="number" placeholder="Coin Cost" className="border p-2 rounded" required />
              <select name="type" className="border p-2 rounded" required>
                <option value="Physical">Physical Item</option>
                <option value="Digital">Digital Purchase</option>
                <option value="Experience">Experience</option>
              </select>
              <input name="imageUrl" placeholder="Image URL (Optional)" className="border p-2 rounded col-span-2" />
            </div>
            <button type="submit" className="w-full bg-green-500 text-white font-bold py-2 rounded">Add Reward</button>
          </form>
        </div>

        <div className="bg-white p-6 rounded-xl shadow">
          <h2 className="text-xl font-bold mb-4">Current Store Items</h2>
          <div className="grid grid-cols-1 gap-4">
            {rewards.map(r => (
              <div key={r.id} className="border p-4 rounded-lg flex gap-4">
                <img src={r.imageUrl} alt={r.title} className="w-16 h-16 object-cover rounded" />
                <div>
                  <h3 className="font-bold text-lg">{r.title}</h3>
                  <span className="text-xs bg-green-100 px-2 py-1 rounded text-green-800">🪙 {r.coinCost}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 bg-gradient-to-br from-indigo-50 to-blue-100 min-h-screen pb-20">
      <header className="flex justify-between items-center mb-6 pt-2">
        <h1 className="text-3xl font-black text-gray-800">Store</h1>
        <div className="flex items-center gap-4">
          <div className="bg-white px-4 py-2 rounded-full shadow-sm">
            <span className="text-sm font-bold text-gray-500 uppercase mr-2">Balance</span>
            <span className="font-black text-green-500">{wallet.balanceCoins} 🪙</span>
          </div>
          <button onClick={() => navigate('/')} className="w-10 h-10 bg-white rounded-full flex items-center justify-center font-bold text-gray-500">✕</button>
        </div>
      </header>

      <div className="grid grid-cols-2 gap-4">
        {rewards.length === 0 ? (
          <div className="col-span-2 text-center p-8 bg-white rounded-3xl shadow-sm text-gray-400 font-medium">Store is empty!</div>
        ) : rewards.map(reward => {
          const canAfford = wallet.balanceCoins >= reward.coinCost;
          return (
            <div key={reward.id} className="bg-white rounded-3xl overflow-hidden shadow-sm flex flex-col">
              <div className="h-32 bg-gray-100 relative">
                <img src={reward.imageUrl} alt={reward.title} className="w-full h-full object-cover" />
                <div className="absolute top-2 right-2 bg-black/50 text-white px-2 py-1 rounded-lg text-xs font-bold">🪙 {reward.coinCost}</div>
              </div>
              <div className="p-4 flex flex-col flex-1">
                <h3 className="font-bold text-sm text-gray-800 mb-1">{reward.title}</h3>
                <div className="mt-auto pt-2">
                  {!canAfford ? (
                    <p className="text-[10px] text-center font-bold text-gray-400 uppercase">Need {reward.coinCost - wallet.balanceCoins} more</p>
                  ) : (
                    <button onClick={() => handleRedeem(reward.id)} className="w-full bg-green-500 text-white font-bold py-2 rounded-xl text-sm">Redeem</button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
INNER_EOF

cat << 'INNER_EOF' > src/App.jsx
import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Login from './pages/Login';
import Home from './pages/Home';
import QuestList from './pages/QuestList';
import Store from './pages/Store';

const PrivateRoute = ({ children }) => {
  const { currentUser } = useAuth();
  return currentUser ? children : <Navigate to="/login" />;
};

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<PrivateRoute><Home /></PrivateRoute>} />
          <Route path="/kid/quests" element={<PrivateRoute><QuestList /></PrivateRoute>} />
          <Route path="/kid/store" element={<PrivateRoute><Store /></PrivateRoute>} />
          <Route path="/parent/quests" element={<PrivateRoute><QuestList /></PrivateRoute>} />
          <Route path="/parent/store" element={<PrivateRoute><Store /></PrivateRoute>} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
INNER_EOF

cat << 'INNER_EOF' > src/main.jsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
createRoot(document.getElementById('root')).render(<App />)
INNER_EOF

cd ..
echo "Regeneration complete!"
