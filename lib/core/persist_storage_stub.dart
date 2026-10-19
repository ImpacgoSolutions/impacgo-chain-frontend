// Used where there is no browser (tests, desktop): nothing is saved.
String? readSaved(String key) => null;
void writeSaved(String key, String value) {}
void clearSaved(String key) {}
void reloadApp() {}
