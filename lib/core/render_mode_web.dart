// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// True when web/flutter_bootstrap.js chose to draw with the processor.
/// The script also sets a cookie ("impacgo_render") that survives reloads, so that is read as well.
bool drawingWithProcessor() {
  try {
    final cookie = html.document.cookie ?? '';
    if (cookie.contains('impacgo_render=cpu')) return true;
    if (cookie.contains('impacgo_render=gpu')) return false;
    // automatic mode: the script records what it chose on the page as a data attribute
    return html.document.documentElement?.getAttribute('data-impacgo-cpu') == 'true';
  } catch (_) {
    return false;
  }
}
