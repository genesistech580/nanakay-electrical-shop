# Electrical Shop Manager

Flutter app for managing shop products, sales, stock, finances, and cloud sync.

## Run in VS Code (persistent browser data)

1. Open `D:\electrical_shop_manager` in VS Code.
2. Open **Run and Debug** and select **Electrical Shop Manager (Chrome)**.
3. Press **F5**. Keep using the same URL: `http://localhost:7357`.

The fixed browser origin matters: browser storage, including the owner PIN and local shop records, is scoped to the URL. Running Chrome on a different random port or using a different hostname can make the browser appear to have a fresh installation. Do not clear browser site data if you want to retain local records.

## Owner access

Set the six-digit owner PIN once. On later runs from the same browser origin, enter that PIN to unlock the shop. The PIN is stored by the platform secure-storage plugin; it is not sent to Supabase. The separate Cloud Sync sign-in uses Supabase Auth.

If you previously ran the app at a different URL/port, open that exact URL and note/export any records there before switching; browser origins have separate data stores.

## Private owner control and Android updates

The owner controls are part of the same app, inside **Cloud sync**. Admin access comes from an approved Supabase account; it is separate from the six-digit local PIN. Only a user ID inserted into `public.app_admins` is an administrator.

### One-time Supabase setup

1. In the app, open **Cloud sync** and create your owner account. Confirm the email if Supabase requests it, then sign in.
2. In the Supabase Dashboard, open **SQL Editor** and run `supabase/migrations/20261031000000_app_owner_control.sql`.
3. In SQL Editor, seed your owner account (replace the example address with the exact email used in step 1):

   ```sql
   insert into public.app_admins (user_id)
   select id from auth.users
   where lower(email) = lower('owner@example.com')
   on conflict (user_id) do nothing;
   ```

4. Return to the app and reopen **Cloud sync**. The **Owner controls** button should appear for the approved account.

The migration allows app installations to read the release/access settings. Only approved admin accounts can change them. Do not put a Supabase service-role key in the Flutter app.

### Manage access and publish a private APK update

- **Pause clients:** Turn off **Allow clients to use the app** and save. Online installations that are not admins are blocked the next time they start. An offline phone cannot receive the change and continues working offline until it reconnects.
- **Publish a release:** Build a new APK with a higher build number in `pubspec.yaml`, upload it to an HTTPS download location you control, then enter its version, build number, and link under **Owner controls**. The app shows clients an update notice; if their build is below **Minimum required build**, it requires an update. Clients download the APK and approve Android's install prompt themselves.
- The APK link is readable by app installations so they can download it. Treat it as a distribution link, not as a secret credential. To limit access, use a host that requires authentication or issue expiring links and refresh the link before clients update.
- These direct APK update controls are for Android. Web builds are updated by deploying the new web build. Native iPhone app updates need an iOS-signed build and a supported distribution method; an Android APK link cannot update iOS.

**Signing matters:** Android only accepts an in-place update when the new APK has the same application ID and signing key as the installed APK. This project currently signs release APKs with the local Android debug key. Keep the same build computer and back up `%USERPROFILE%\.android\debug.keystore` before distributing updates. Losing or changing that key means Android will reject an update; installing a differently signed build may require uninstalling the old app, which removes its local data. Set up a permanent release keystore before broad distribution.

If **Owner controls** does not appear, verify that the migration was run, the seed statement matched the owner's Supabase email, and the owner is signed in under **Cloud sync**.
## Checks

```powershell
flutter analyze
flutter test
```

## Install the native iPhone app

The project includes a native Flutter iOS app in `ios/`. Building or installing it requires a Mac with Xcode; Windows cannot run Apple's iOS build tools.

1. Copy or clone this project onto the Mac and install Flutter plus Xcode.
2. In Terminal, open the project folder and run `flutter pub get`.
3. Connect the iPhone, unlock it, and trust the Mac if prompted.
4. Open `ios/Runner.xcworkspace` in Xcode. Select the **Runner** target, then **Signing & Capabilities**. Sign in with an Apple ID, select your development Team, and leave **Automatically manage signing** enabled. The app identifier is `com.genesistech.nanakayelectricalshop`; change it if Xcode reports that it is already in use.
5. Select the connected iPhone as the run destination and press **Run**, or return to Terminal and run `flutter run -d <device-id>`.

A free Apple ID can sign an app for personal testing, with Apple's device and provisioning limits. App Store distribution requires enrollment in the Apple Developer Program and App Store Connect setup.