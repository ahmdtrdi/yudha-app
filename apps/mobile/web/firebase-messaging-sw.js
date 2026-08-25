importScripts("https://www.gstatic.com/firebasejs/12.18.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/12.18.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBiNbspKr2WzCAwQcPepazBZxI404KzXNY",
  authDomain: "yudha-app.firebaseapp.com",
  projectId: "yudha-app",
  storageBucket: "yudha-app.firebasestorage.app",
  messagingSenderId: "218293126626",
  appId: "1:218293126626:web:059eb23a0868c98e9ea5bb",
  measurementId: "G-LV36KDJQWQ",
});

firebase.messaging().onBackgroundMessage(() => {
  // Notification payloads are rendered by FCM. The callback keeps the worker
  // initialized for data delivery without creating a duplicate notification.
});
