# Setup Guide - closr App

Step-by-step guide to configure Firebase and get the app running.

## Step 1: Create a Firebase Project

1. Visit [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project"
3. Enter project name: `closr-app`
4. Follow the setup wizard (disable Google Analytics for now if you want)
5. Once created, you'll be in the Firebase project dashboard

## Step 2: Register Your App with Firebase

### For Android:

1. In Firebase Console, click "Add app" → Android
2. Enter package name: `com.example.closr_app`
3. Enter app nickname: `closr Android`
4. Follow the steps to download `google-services.json`
5. Place it in: `android/app/google-services.json`

### For iOS:

1. In Firebase Console, click "Add app" → iOS
2. Enter iOS bundle ID: `com.example.closrApp`
3. Enter app nickname: `closr iOS`
4. Download `GoogleService-Info.plist`
5. Don't follow the manual steps - FlutterFire will handle this

## Step 3: Enable Required Firebase Services

In Firebase Console:

### Authentication
1. Go to **Authentication** → **Sign-in method**
2. Enable **Email/Password** provider
3. Enable **Google** provider
4. Add your email to **Authorized testing accounts** (for testing purposes)
5. Note the Web Client ID from Google settings (you may need this for iOS)

### Firestore Database
1. Go to **Firestore Database** → **Create database**
2. Choose location (closest to your users)
3. Start in **Production mode** (we'll apply security rules)
4. Click **Create**

## Step 4: Apply Firestore Security Rules

1. In Firestore Database, go to **Rules** tab
2. Copy the content from `firestore.rules` file in the project root
3. Paste it into the rules editor
4. Click **Publish**

## Step 5: Register Your App for Google Sign-In

### For Android:

1. Get your app's SHA-1 fingerprint:
   ```bash
   cd android && ./gradlew signingReport
   ```
2. Copy the SHA-1 hash
3. In Firebase Console → **Project Settings** → **Your apps**
4. Click on Android app → **Add fingerprint**
5. Paste the SHA-1 and save

### For iOS:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Replace the bundle identifier with your actual identifier
3. Configure signing with your Apple Developer account
4. Firebase will automatically validate during setup

## Step 6: Configure FlutterFire

1. Ensure you have FlutterFire CLI installed:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure your project:
   ```bash
   flutterfire configure
   ```

3. Select the Firebase project you created
4. Select the platforms you want to configure (iOS and/or Android)
5. FlutterFire will automatically:
   - Download credentials
   - Generate `lib/config/firebase_options.dart`
   - Configure your iOS and Android projects

## Step 7: Add GoogleService-Info.plist (iOS)

1. Run `flutterfire configure` (should have done this above)
2. Open `ios/Runner.xcworkspace` in Xcode
3. Add `GoogleService-Info.plist` to the Runner target (if not already done)
4. Ensure it's included in "Copy Bundle Resources" build phase

## Step 8: Test the App

1. **Get dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run on iOS:**
   ```bash
   flutter run -d ios
   ```
   Or open `ios/Runner.xcworkspace` in Xcode and build from there.

3. **Run on Android:**
   ```bash
   flutter run -d android
   ```

## Testing Flows

### Email/Password Sign-Up
1. On the login screen, toggle to "Create Account"
2. Enter email, display name, and password (min 6 chars)
3. Click "Create Account"
4. Should see onboarding with role selection

### Email/Password Sign-In
1. Enter the credentials you just created
2. If role already assigned, goes directly to home
3. If new user, shows onboarding

### Google Sign-In
1. Click "Continue with Google"
2. Select your Google account
3. Should see onboarding for first-time users
4. Already onboarded users go straight to home

## Troubleshooting

### Firebase won't initialize
**Problem:** "Could not find Firebase credentials"
**Solution:**
1. Verify `flutterfire configure` completed successfully
2. Check that `lib/config/firebase_options.dart` exists and has real values
3. Delete and run `flutterfire configure` again

### Google Sign-In fails on Android
**Problem:** "GoogleSignInException"
**Solution:**
1. Get your app's SHA-1: `cd android && ./gradlew signingReport`
2. Add SHA-1 to Firebase Console → Project Settings → Your apps
3. Clean and rebuild: `flutter clean && flutter pub get && flutter run`

### Google Sign-In fails on iOS
**Problem:** "Cannot find GoogleService-Info.plist"
**Solution:**
1. Verify `GoogleService-Info.plist` is in Xcode project
2. Verify it's in "Copy Bundle Resources" build phase
3. Check file permissions: `ls -la ios/Runner/GoogleService-Info.plist`

### Firestore permission denied
**Problem:** "Missing or insufficient permissions"
**Solution:**
1. Ensure user is authenticated (signed in)
2. Check Firestore rules in Firebase Console
3. Verify rules were published (not just in edit mode)
4. Clear app data and try again

## Next Steps

Once the app is running:

1. **Extend the home screen** with actual creator/subscriber features
2. **Implement messaging** with Firestore real-time listeners
3. **Add Stripe integration** for subscription payments
4. **Set up Cloud Functions** for webhook handling
5. **Configure push notifications** with FCM

See the main README.md for more details on architecture and features.
