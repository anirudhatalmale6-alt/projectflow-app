// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void navigateToUrl(String url) {
  html.window.location.href = url;
}

void replaceCurrentUrl(String url) {
  html.window.history.replaceState(null, '', url);
}
