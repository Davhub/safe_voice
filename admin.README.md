Safe Voice — Admin Dashboard

This folder contains a Flutter web admin dashboard integrated into the main repo.

How to run locally

1. Ensure you have Flutter with web enabled:

```bash
flutter config --enable-web
flutter pub get
```

2. Run the admin app in Chrome:

```bash
flutter run -d chrome --target=lib/admin/admin_main.dart
```

Build for production

```bash
flutter build web --target=lib/admin/admin_main.dart --web-renderer html
```

Deploy to Firebase Hosting

1. Install firebase-tools: `npm i -g firebase-tools`
2. `firebase login`
3. `firebase init hosting` (select existing project, set public dir to `build/web`)
4. `firebase deploy --only hosting`
