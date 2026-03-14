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
