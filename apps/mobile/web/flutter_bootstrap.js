{{flutter_js}}
{{flutter_build_config}}

// YUDHA registers its own service worker from index.html. Keeping the Flutter
// loader free of serviceWorkerSettings prevents two workers competing for "/".
_flutter.loader.load();
