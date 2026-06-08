# App Usage Analytics Integration Guide

## Overview
This guide explains how to integrate anonymous, aggregated analytics tracking into the Safe Voice mobile app to populate the real-time analytics dashboard.

## Architecture

### Data Structure
```
Firebase Firestore:
/app_usage_analytics/
  ├── daily/
  │   └── metrics/
  │       ├── 2026-01-14/          # Daily metrics
  │       ├── 2026-01-15/
  │       └── ...
  └── monthly/
      └── metrics/
          ├── 2026-01/             # Monthly metrics
          ├── 2026-02/
          └── ...
```

### Privacy Guarantees
- ✅ No user identifiers (no user IDs, device IDs, or IP addresses)
- ✅ All data aggregated at collection time
- ✅ Location limited to country level only (extracted from anonymous location data)
- ✅ Real-time updates using Firebase Firestore streams
- ✅ Compliant with child protection and data privacy regulations

## Client-Side Integration

### 1. Track App Opens
Add this to your app's main.dart or app initialization:

```dart
import 'package:safe_voice/admin/services/app_usage_analytics_service.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Track app open
  await _trackAppOpen();
  
  runApp(MyApp());
}

Future<void> _trackAppOpen() async {
  try {
    // Get device type (anonymous)
    final deviceType = Platform.isAndroid ? 'android' : 'iOS';
    
    // Get country from device locale (anonymous, coarse location)
    final country = _getCountryFromLocale();
    
    // Increment app open metric
    await AppUsageAnalyticsService.incrementMetric(
      metricType: 'appOpen',
      deviceType: deviceType,
      country: country,
    );
    
    // Track active user (uses anonymous session)
    await AppUsageAnalyticsService.incrementMetric(
      metricType: 'activeUser',
      deviceType: deviceType,
      country: country,
    );
  } catch (e) {
    debugPrint('Analytics tracking error: $e');
    // Fail silently - don't disrupt user experience
  }
}

String _getCountryFromLocale() {
  try {
    final locale = Platform.localeName; // e.g., "en_US"
    final parts = locale.split('_');
    return parts.length > 1 ? parts[1] : 'Unknown';
  } catch (e) {
    return 'Unknown';
  }
}
```

### 2. Track Screen Visits
Add analytics tracking to navigation events:

```dart
// In your Navigator observers or route changes
class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenVisit(route.settings.name);
  }
  
  void _trackScreenVisit(String? routeName) {
    if (routeName == null) return;
    
    // Map route names to screen identifiers
    String? screenName;
    switch (routeName) {
      case '/home':
        screenName = 'home';
        break;
      case '/report':
        screenName = 'reportSubmitted';
        break;
      case '/about':
        screenName = 'aboutUs';
        break;
      case '/resources':
        screenName = 'resources';
        break;
    }
    
    if (screenName != null) {
      AppUsageAnalyticsService.incrementMetric(
        metricType: 'screenVisit',
        screen: screenName,
      ).catchError((e) {
        debugPrint('Screen visit tracking error: $e');
      });
    }
  }
}

// Add to MaterialApp:
MaterialApp(
  navigatorObservers: [AnalyticsObserver()],
  // ... rest of config
)
```

### 3. Track Report Submissions
Add tracking when a report is successfully submitted:

```dart
// In your report submission logic
Future<void> submitReport() async {
  // ... existing report submission code
  
  // After successful submission, track the screen visit
  await AppUsageAnalyticsService.incrementMetric(
    metricType: 'screenVisit',
    screen: 'reportSubmitted',
  ).catchError((e) {
    debugPrint('Report submission tracking error: $e');
  });
}
```

## Production Considerations

### 1. Use Cloud Functions for Write Security
For production, implement Cloud Functions to handle analytics writes instead of allowing direct client writes:

```javascript
// Firebase Cloud Function example
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.trackAnalytics = functions.https.onCall(async (data, context) => {
  // Validate request
  const { metricType, screen, deviceType, country } = data;
  
  // Get current date keys
  const now = new Date();
  const dateKey = now.toISOString().split('T')[0]; // YYYY-MM-DD
  const monthKey = now.toISOString().substring(0, 7); // YYYY-MM
  
  // Update daily and monthly metrics atomically
  const db = admin.firestore();
  const batch = db.batch();
  
  // Daily update
  const dailyRef = db.collection('app_usage_analytics')
    .doc('daily')
    .collection('metrics')
    .doc(dateKey);
    
  batch.set(dailyRef, {
    // ... increment logic
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  
  // Monthly update (same logic)
  // ...
  
  await batch.commit();
  return { success: true };
});
```

### 2. Firestore Security Rules
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Analytics data is read-only from client
    // Writes should go through Cloud Functions
    match /app_usage_analytics/{document=**} {
      allow read: if request.auth != null; // Admins only
      allow write: if false; // Use Cloud Functions
    }
  }
}
```

### 3. Initialize Analytics Structure
Run this once during initial setup or through an admin script:

```dart
// In admin panel or setup script
await AppUsageAnalyticsService.initializeAnalyticsStructure();
```

## Testing

### Manual Testing
1. Initialize analytics structure (button in empty state)
2. Use the client app and perform actions
3. Check the admin dashboard - data should update in real-time
4. Switch between time periods (Today, Week, Month)

### Verify Data Structure
Check Firestore console:
```
app_usage_analytics/daily/metrics/2026-01-14
{
  activeUsers: 45,
  appOpens: 67,
  screenVisits: {
    home: 45,
    reportSubmitted: 34,
    aboutUs: 12,
    resources: 8
  },
  deviceTypes: {
    android: 28,
    iOS: 17
  },
  coarseLocations: {
    KE: 25,  // Kenya
    UG: 10,  // Uganda
    TZ: 8    // Tanzania
  },
  lastUpdated: Timestamp
}
```

## Monitoring & Maintenance

### Check Analytics Health
- Monitor Firestore read/write costs
- Set up alerts for missing daily documents
- Review data retention policies (consider aggregating old data)

### Data Retention
Consider implementing Cloud Functions to:
- Archive old daily metrics after 90 days
- Keep monthly metrics indefinitely
- Create yearly aggregates for long-term trends

## Future Enhancements
- [ ] Add case type breakdown in analytics
- [ ] Track report resolution time metrics
- [ ] Add user journey funnel analysis (anonymous)
- [ ] Implement custom date range selector
- [ ] Add export functionality for reports
- [ ] Create automated daily/weekly reports
