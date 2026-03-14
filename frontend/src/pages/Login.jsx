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
