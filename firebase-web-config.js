// Import the functions you need from the SDKs you need
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut, onAuthStateChanged } from 'firebase/auth';
import { getFirestore, collection, addDoc, getDocs, query, orderBy, limit } from 'firebase/firestore';
import { getStorage, ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { getAnalytics } from 'firebase/analytics';

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBXy89aYxkfImhy6LYiAP-84DoZHY87ITY",
  authDomain: "mychannel-ca26d.firebaseapp.com",
  projectId: "mychannel-ca26d",
  storageBucket: "mychannel-ca26d.firebasestorage.app",
  messagingSenderId: "124515086975",
  appId: "1:124515086975:ios:f3683f5fb93c02d2c3454a",
  measurementId: "G-XXXXXXXXXX" // You'll get this from Firebase Analytics
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);
const analytics = getAnalytics(app);

export { auth, db, storage, analytics, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut, onAuthStateChanged, collection, addDoc, getDocs, query, orderBy, limit, ref, uploadBytesResumable, getDownloadURL };
