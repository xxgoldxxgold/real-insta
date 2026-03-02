// Push Notification Service Worker for Real-Insta
self.addEventListener('push', function(event) {
  var data = { title: 'Real-Insta', body: '新しいメッセージ', icon: '/favicon.png', badge: '/favicon.png', data: {} };
  if (event.data) {
    try { data = Object.assign(data, event.data.json()); } catch (e) {}
  }
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: data.icon || '/favicon.png',
      badge: data.badge || '/favicon.png',
      data: data.data || {},
      vibrate: [200, 100, 200],
      tag: 'dm-' + (data.data && data.data.conversation_id || 'general'),
      renotify: true,
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  var url = '/';
  if (event.notification.data && event.notification.data.conversation_id) {
    url = '/#/dm/' + event.notification.data.conversation_id;
  }
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url.indexOf('real-insta.com') !== -1 && 'focus' in client) {
          client.navigate(url);
          return client.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
