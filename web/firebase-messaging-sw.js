importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBuxVN_5B-fr5Ot5vCbxrQThAZ7wEVd0w0',
  authDomain: 'real-insta-push.firebaseapp.com',
  projectId: 'real-insta-push',
  storageBucket: 'real-insta-push.firebasestorage.app',
  messagingSenderId: '786647205162',
  appId: '1:786647205162:web:d20af03591f90bca2f8a53',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const d = payload.data || {};
  const title = d.title || 'Real-Insta';
  const options = {
    body: d.body || '',
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: {
      url: d.url || '/',
      type: d.type || '',
      conversation_id: d.conversation_id || '',
    },
    vibrate: [200, 100, 200],
    tag: 'dm-' + (d.conversation_id || 'general'),
    renotify: true,
  };
  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const url = data.url || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.focus();
          client.postMessage({ type: 'notification_click', url: url, data: data });
          return;
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
