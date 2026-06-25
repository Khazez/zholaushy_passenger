importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyC5k6vD8moo1cF8ewdF3H-RLx8tslz9a5c",
  authDomain: "taxi-b163c.firebaseapp.com",
  projectId: "taxi-b163c",
  storageBucket: "taxi-b163c.firebasestorage.app",
  messagingSenderId: "1054390633030",
  appId: "1:1054390633030:web:76ec102fd5b22f0d2a0047",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification.title;
  const options = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png",
  };
  self.registration.showNotification(title, options);
});
