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
