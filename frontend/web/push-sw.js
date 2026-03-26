// Push Notification Service Worker for Duozz Flow
self.addEventListener('push', function(event) {
  var data = { title: 'Duozz Flow', body: 'Nova notificacao', icon: '/icons/Icon-192.png' };
  try {
    if (event.data) {
      data = event.data.json();
    }
  } catch (e) {
    if (event.data) {
      data.body = event.data.text();
    }
  }

  var options = {
    body: data.body || '',
    icon: data.icon || '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: data.data || {},
    actions: [
      { action: 'open', title: 'Abrir' },
      { action: 'dismiss', title: 'Fechar' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'Duozz Flow', options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  if (event.action === 'dismiss') return;

  // Navigate to the app
  var url = '/';
  var notifData = event.notification.data || {};
  if (notifData.referenceType === 'task' && notifData.referenceId) {
    url = '/tasks/detail?id=' + notifData.referenceId;
  } else if (notifData.referenceType === 'project' && notifData.referenceId) {
    url = '/projects/detail?id=' + notifData.referenceId;
  } else if (notifData.referenceType === 'delivery' && notifData.referenceId) {
    url = '/deliveries/detail?id=' + notifData.referenceId;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // Focus existing window if available
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url.includes(self.location.origin)) {
          client.navigate(url);
          return client.focus();
        }
      }
      // Open new window
      return clients.openWindow(url);
    })
  );
});

// Keep service worker alive
self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(self.clients.claim());
});
