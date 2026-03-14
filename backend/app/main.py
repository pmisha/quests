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
