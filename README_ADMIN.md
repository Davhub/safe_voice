Safe Voice — Admin dashboard

Overview

This file documents how to run, build, and deploy the admin web dashboard added under lib/admin. It also includes a handoff checklist and a template for owner/admin credentials to record when handing over access.

Quick run (development)

1. Install dependencies:
   flutter pub get

2. Run the admin app in Chrome:
   flutter run -d chrome --target=lib/admin/admin_main.dart

Build (production web)

1. Build web output for the admin entrypoint:
   flutter build web --target=lib/admin/admin_main.dart --web-renderer html

2. The produced files will be in build/web.

Deploy to Firebase Hosting

Prerequisites:
- Install Firebase CLI: https://firebase.google.com/docs/cli#install_the_firebase_cli
- Authenticate: firebase login
- Ensure this project is connected to the correct Firebase project (firebase use <project-id> or firebase init hosting and select the project).

Steps:
1. Ensure build/web exists (see Build section).
2. Deploy:
   firebase deploy --only hosting

Firebase Hosting config

A hosting config has been added to firebase.json to serve build/web and rewrite all routes to index.html (SPA). Verify projectId and site settings in the Firebase Console if the project differs.

Admin account bootstrap

A one-shot admin creation script is included at lib/admin/setup/create_admin.dart. Use this after running flutter pub get and initializing Firebase to create the first admin user and Firestore doc in the "admins" collection.

Security notes

- The admin app checks the admins collection in Firestore to authorize privileged actions. Add/remove admin documents manually or via the admin creation script.
- Consider adding and publishing Firestore security rules to restrict update/delete operations to members of the admins collection.

Handoff checklist (for owner)

- [ ] Confirm Firebase project used by the mobile app is the intended project for admin hosting.
- [ ] Confirm firebase.json hosting config projectId/site is correct.
- [ ] Install Firebase CLI and run firebase login.
- [ ] Build the admin web app and deploy to hosting.
- [ ] Create at least one admin account and record credentials (see template below).
- [ ] Review and publish Firestore security rules to enforce admin-only writes.

Owner/admin credentials template (store safely)

- Admin email: __________________
- Admin temporary password: __________________
- Created by (dev): __________________
- Date created: __________________
- Notes (password rotation policy, MFA, contact): __________________

Contact

If anything is unclear with the admin dashboard, refer to the README in the project root or contact the developer who implemented the admin dashboard.

Firestore rules and deploying them

1. A minimal rules file has been added at `firestore.rules` in the repository.
2. To deploy Firestore rules with the Firebase CLI:

```bash
# Ensure you're using the correct project
firebase use <project-id>

# Deploy only rules
firebase deploy --only firestore:rules

# Or deploy hosting + rules together
firebase deploy --only hosting,firestore:rules
```

3. Verify rule behavior in the Firebase Console (Firestore -> Rules) and test with the Rules simulator before publishing to production.

Notes

- The provided `firestore.rules` is intentionally minimal — review and adapt it to your data model and security needs before publishing.
- Admin documents should be created via secure server-side tooling or the Firebase Console; the included `lib/admin/setup/create_admin.dart` is a convenience script for initial setup and must be run securely.
