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
