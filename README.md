# closr - Mobile Messaging App

A Flutter-based mobile app for creators to monetize 1-on-1 conversations with paid subscribers.

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Authentication**: Firebase Auth + Google Sign-In
- **Database**: Cloud Firestore
- **Payments**: Stripe (coming soon)
- **Notifications**: Firebase Cloud Messaging (coming soon)

## Features Implemented

- ✅ Firebase Auth integration
- ✅ Google Sign-In with email/password fallback
- ✅ Onboarding screen with role selection (Creator/Subscriber)
- ✅ User profile storage in Firestore
- ✅ Responsive mobile-first UI
- ✅ Authentication state management

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Firebase project (create at [console.firebase.google.com](https://console.firebase.google.com))
- Google Cloud project (for Google Sign-In)
- Xcode (for iOS development)
- Android Studio (for Android development)

### Installation

1. **Clone the repository**
   ```bash
   cd closr-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   ```bash
   # Install FlutterFire CLI if not already installed
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure
   ```
   This will automatically generate `lib/config/firebase_options.dart` with your Firebase credentials.

4. **Set up Google Sign-In**
   
   **iOS:**
   - Go to your Firebase project settings
   - Download GoogleService-Info.plist
   - Open `ios/Runner.xcworkspace` in Xcode
   - Add GoogleService-Info.plist to the Runner target
   
   **Android:**
   - The `flutterfire configure` command handles this automatically

5. **Enable Firebase services**
   
   In Firebase Console:
   - **Authentication**: Enable Email/Password and Google Sign-In
   - **Firestore Database**: Create in production mode
   - **Firestore Rules**: Apply the rules from `firestore.rules` file

### Running the App

```bash
# Run on all devices
flutter run

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android

# Run in release mode
flutter run --release
```

## Project Structure

```
lib/
├── main.dart                  # App entry point & auth routing
├── config/
│   └── firebase_options.dart  # Firebase configuration (auto-generated)
├── models/
│   └── user_model.dart        # AppUser model
├── services/
│   ├── auth_service.dart      # Firebase Auth & Google Sign-In
│   └── firestore_service.dart # Firestore operations
├── screens/
│   ├── login_screen.dart      # Login/Sign-up UI
│   ├── onboarding_screen.dart # Role selection
│   └── home_screen.dart       # Main app screen
└── widgets/
    └── loading_overlay.dart   # Loading indicator
```

## Firebase Firestore Structure

### Collections

**users**
```
/users/{uid}
├── uid: string
├── email: string
├── displayName: string
├── role: string (creator | subscriber)
├── photoUrl: string (optional)
├── createdAt: timestamp
├── updatedAt: timestamp
└── isActive: boolean
```

## Next Steps

1. **Implement Messaging**
   - Create messages collection
   - Set up real-time message streaming
   - Build chat UI

2. **Stripe Integration**
   - Create subscriptions collection
   - Implement checkout flow
   - Set up webhook handlers

3. **Push Notifications**
   - Configure Firebase Cloud Messaging (FCM)
   - Send notifications for new messages

4. **Creator Features**
   - Analytics dashboard
   - Subscriber management
   - Payout settings

5. **Subscriber Features**
   - Creator discovery/search
   - Subscription management
   - Payment history

## Security

- All Firestore rules enforce user authentication
- User data access is restricted to the user themselves and authorized connections
- Sensitive operations (role changes, subscriptions) are validated server-side via Cloud Functions

## Troubleshooting

### Firebase not initializing
- Verify `flutterfire configure` output
- Check that GoogleService-Info.plist (iOS) or google-services.json (Android) exist
- Ensure Firebase services are enabled in the Firebase Console

### Google Sign-In not working
- iOS: Verify GoogleService-Info.plist is added to Xcode
- Android: Ensure SHA-1 fingerprint is registered in Firebase Console
  ```bash
  # Get your app's SHA-1
  cd android && ./gradlew signingReport
  ```

### Firestore permission errors
- Check Firestore rules (console.firebase.google.com)
- Verify user is authenticated
- Check browser console for error details

## Contributing

When adding new features:
1. Create a new branch
2. Make changes
3. Test on both iOS and Android
4. Submit pull request

## License

MIT License - see LICENSE file for details

## Support

For issues or questions, create an issue in the GitHub repository.
