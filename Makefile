.PHONY: build-web clean

build-web:
	@echo "Building Flutter web app..."
	flutter build web
	@echo "Patching service worker..."
	dart tool/patch_service_worker.dart
	@echo "Build complete!"

clean:
	flutter clean
