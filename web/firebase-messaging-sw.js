importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDxSQfH-Ze2hv7skgm8FPHUTfKGQSVId9o",
  authDomain: "kooked-28d4c.firebaseapp.com",
  projectId: "kooked-28d4c",
  storageBucket: "kooked-28d4c.firebasestorage.app",
  messagingSenderId: "112296499639",
  appId: "1:112296499639:web:92c0b01891da9e7b49f032"
});

const messaging = firebase.messaging();
