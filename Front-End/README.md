# TokoKita Front-End

Flutter Android client for the TokoKita storefront and admin dashboard.
Backend services are Supabase Auth/Postgres/Edge Functions and Midtrans Snap;
see [Back-End/README.md](../Back-End/README.md) for deployment details.

## Local setup

1. Copy `config/local.example.json` to `config/local.json`.
2. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to the project's public values.
   Never put a Supabase service-role key or Midtrans server key in this file.
3. Run:

```shell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/local.json
```

`config/local.json` is ignored by Git. Without Supabase configuration, the app
opens in guest mode; account, inventory, order, and support features require a
working Supabase connection.

## Current structure

```text
lib/
  config/     Compile-time public client configuration
  data/       Static product descriptions and presentation data
  models/     Product, role, and order status types
  screens/    Customer and admin screens
  services/   Supabase-facing auth, address, order, and chat operations
  theme/      App colors, typography, and Material theme
  widgets/    Reusable controls and product/checkout UI
test/         Unit and widget tests
android/      Android app and Gradle configuration
assets/       Product and brand images
```

Product descriptions and images are local catalog content; active product
stock is loaded from Supabase. Checkout, order status, chat, and saved addresses
use backend services. Promotion inventory, customer reviews, and a complete
account-recovery deep link are not yet implemented.

## Android release signing

Do not use the debug key for a release. Create an upload key outside source
control, then put the keystore at `android/app/upload-keystore.jks` and create
`android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Both files are ignored by Git. Back up the keystore and passwords securely;
losing the upload key can block future Play Store updates. Build a signed
Android App Bundle with:

```shell
flutter build appbundle --release --dart-define-from-file=config/local.json
```

The bundle is written to
`build/app/outputs/bundle/release/app-release.aab`. The repository currently
contains Android configuration only; iOS, web, and desktop releases are not
configured.
