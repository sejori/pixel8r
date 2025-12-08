import 'dart:io';

void main() async {
  final file = File('build/web/flutter_service_worker.js');
  if (!await file.exists()) {
    print('Error: build/web/flutter_service_worker.js not found. Run "flutter build web" first.');
    exit(1);
  }

  String content = await file.readAsString();

  const String oldCode = r'''
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );''';

  const String newCode = r'''
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        var fetchPromise = fetch(event.request).then((networkResponse) => {
          if (networkResponse && Boolean(networkResponse.ok)) {
            cache.put(event.request, networkResponse.clone());
          }
          return networkResponse;
        });
        if (response) {
          event.waitUntil(fetchPromise.catch(() => {}));
          return response;
        }
        return fetchPromise;
      })
    })
  );''';

  if (content.contains(oldCode)) {
    content = content.replaceFirst(oldCode, newCode);
    await file.writeAsString(content);
    print('Successfully patched flutter_service_worker.js with Stale-While-Revalidate strategy.');
  } else {
    print('Warning: Could not find the specific code block to patch. The file might have changed or is already patched.');
    // Optional: print a snippet of what we found to debug
    // print('Content snippet: ' + content.substring(content.indexOf('event.respondWith'), content.indexOf('event.respondWith') + 200));
  }
}
