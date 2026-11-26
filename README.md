# TokoKita

Repository ini dipisahkan berdasarkan area aplikasi:

```text
TokoKita/
├── Front-End/   # Aplikasi Flutter
├── Back-End/    # Supabase SQL migrations dan Edge Functions Midtrans
└── .gitignore   # Aturan Git untuk seluruh repository
```

## Menjalankan aplikasi

Salin `Front-End/config/local.example.json` menjadi
`Front-End/config/local.json`, lalu isi URL proyek dan publishable/anon key
Supabase. File konfigurasi lokal tersebut diabaikan Git.

```bash
cd Front-End
flutter pub get
flutter run --dart-define-from-file=config/local.json
```

## Distribusi langsung dan transaksi

Aplikasi tidak perlu diunggah ke Play Store atau App Store. Setelah Supabase
dan Midtrans Sandbox dikonfigurasi serta alur checkout, webhook, dan perubahan
status pesanan berhasil diuji, APK Android dapat dibuat untuk dipasang langsung.
Build release harus menggunakan upload key pribadi; ikuti petunjuk signing di
[Front-End/README.md](./Front-End/README.md). Jangan gunakan debug key untuk
distribusi:

```bash
flutter build apk --release --dart-define-from-file=config/local.json
```

APK berada di `Front-End/build/app/outputs/flutter-apk/app-release.apk`.
Perangkat tetap memerlukan koneksi internet untuk autentikasi, stok/pesanan
Supabase, dan konfirmasi pembayaran Midtrans. Gunakan mode produksi hanya
setelah pengujian Sandbox menyelesaikan seluruh alur transaksi.

Petunjuk deploy Supabase, konfigurasi Midtrans, dan penyiapan admin ada di
[Back-End/README.md](./Back-End/README.md).
