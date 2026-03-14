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
