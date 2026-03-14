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
