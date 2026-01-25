importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDMDZz2pbubPpPwz0DnBtUG9R7BZ0Pr-L4",
  authDomain: "atmetny.firebaseapp.com",
  projectId: "atmetny",
  storageBucket: "atmetny.firebasestorage.app",
  messagingSenderId: "386239634560",
  appId: "1:386239634560:web:9a0ecbcdd07ad2a8fcda65",
  measurementId: "G-QZWHJ4KHDM"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'إشعار جديد';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
