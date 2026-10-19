// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// The browser's local storage. A private window or blocked storage can throw, so every call is guarded.
String? readSaved(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void writeSaved(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void clearSaved(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}

void reloadApp() => html.window.location.reload();
