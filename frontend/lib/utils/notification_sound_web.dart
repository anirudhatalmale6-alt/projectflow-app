import 'dart:js' as js;

void playNotificationSound() {
  try {
    js.context.callMethod('playDuozzNotificationSound');
  } catch (_) {}
}
