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
