import 'dart:js' as js;

void playNotificationSound() {
  try {
    js.context.callMethod('playDuozzNotificationSound');
  } catch (_) {}
}

void initPushNotifications(String authToken) {
  try {
    js.context.callMethod('initPushNotifications', [authToken]);
  } catch (_) {}
}
