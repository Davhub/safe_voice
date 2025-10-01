# Firebase Setup Guide for Safe Voice

## ⚠️ CRITICAL: Authorization Error Fix

If you're getting the error `[firebase_storage/unauthorized] user is not authorized to perform the desired action`, you need to update your Firebase Storage rules immediately. See the **Security Rules for Storage** section below and apply the rules to your Firebase Console.

## 1. Firestore Database Setup

### Required Collections:

#### `reports` collection:
- **Document ID**: Auto-generated
- **Fields**:
  ```
  caseId: string
  type: string (text, voice, mixed)
  content: string (optional - for text reports)
  audioUrl: string (optional - for voice reports)
  location: string (optional)
  incidentDate: timestamp (optional)
  submittedAt: timestamp
  attachments: array of strings
  status: string (submitted, under_review, reviewed, closed, requires_follow_up)
  anonymous: boolean (always true)
  ```

#### Security Rules for Firestore:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow anonymous users to create reports only
    match /reports/{document} {
      allow create: if true; // Allow anonymous report creation
      allow read, update, delete: if false; // Prevent reading/modifying for privacy
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## 2. Firebase Storage Setup

### Required Structure:
```
/reports/
  /{caseId}/
    /audio/
      - voice_report.m4a (or other audio formats)
    /attachments/
      - attachment1.jpg
      - attachment2.pdf
      - etc.
```

#### Security Rules for Storage:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow anonymous users to upload voice reports and get download URLs
    match /voice_reports/{caseId}/{fileName} {
      allow write: if true; // Allow anonymous uploads
      allow read: if request.auth == null; // Allow anonymous read for download URLs only
    }
    
    match /attachments/{caseId}/{fileName} {
      allow write: if true; // Allow anonymous uploads  
      allow read: if request.auth == null; // Allow anonymous read for download URLs only
    }
    
    // Support legacy reports structure for backward compatibility
    match /reports/{caseId}/{allPaths=**} {
      allow write: if true; // Allow anonymous uploads
      allow read: if request.auth == null; // Allow anonymous read for download URLs only
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## 3. Steps to Apply:

1. **Firestore Database**:
   - Go to Firebase Console > Firestore Database
   - Create database in test mode
   - Go to Rules tab and paste the Firestore rules above
   - Publish the rules

2. **Firebase Storage**:
   - Go to Firebase Console > Storage
   - Get started in test mode
   - Go to Rules tab and paste the Storage rules above
   - Publish the rules

3. **Test Collection** (Optional):
   - Create a test document in the `reports` collection manually
   - Add sample data to verify the structure

## 4. Network Configuration

If using Android Emulator, ensure it has internet access:
- Cold boot the emulator
- Check network settings in emulator
- Use a different emulator if needed (API 30 or 31 recommended)

## 5. Firebase Rules (Production Ready)

For production, use more restrictive rules:

### Firestore (Production):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /reports/{document} {
      // Allow create for anonymous users
      allow create: if true;
      // Allow read only for specific case queries
      allow read: if resource.data.caseId == request.query.where[0][2];
    }
  }
}
```

### Storage (Production):
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /reports/{caseId}/{allPaths=**} {
      // Allow upload for new reports
      allow write: if true;
      // Allow read only for valid case IDs
      allow read: if true;
    }
  }
}
```
