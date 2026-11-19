# TokoKita — E-Commerce & Lifestyle Platform

TokoKita adalah aplikasi katalog dan belanja online berbasis Flutter yang dirancang dengan standar desain profesional, antarmuka yang bersih, serta pengalaman pengguna yang responsif.

## Fitur Utama

- **Layar Masuk (Welcome Screen)**: Autentikasi selamat datang dengan sapaan personal menggunakan nama lengkap pengguna.
- **Beranda & Katalog Produk**: 
  - Karosel promo interaktif dan pencarian produk cerdas (*smart multi-token search*).
  - Filter kategori produk (Elektronik, Pakaian, Aksesoris) dengan penyusunan katalog beranda yang dinamis.
  - Kartu produk dalam bentuk *Grid* dan *List* yang dilengkapi lencana mall dan diskon.
- **Detail Produk**: Galeri gambar, pilihan varian ukuran & warna, ulasan pengguna, dan panel aksi cepat (*Beli Sekarang* & *Keranjang*).
- **Keranjang & Checkout**: Pengelolaan kuantitas barang, pemilihan item, dan simulasi pembayaran instan.
- **Konfirmasi Pesanan Sukses**: Layar ringkasan transaksi dengan nomor referensi pesanan.

## Panduan Menjalankan Aplikasi

Pastikan Flutter SDK sudah terinstal di komputer Anda. Buka terminal pada folder proyek, lalu jalankan perintah berikut:

```bash
# Mengunduh dependensi
flutter pub get

# Memeriksa perangkat yang terhubung
flutter devices

# Menjalankan aplikasi dalam mode debug
flutter run
```

## Membangun Berkas APK Debug

Untuk menghasilkan berkas APK debug secara mandiri, jalankan:

```bash
flutter build apk --debug
```

Berkas keluaran akan tersedia di:
```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Struktur Proyek

```text
TokoKita/
├── android/                   # Konfigurasi native Android & Splash
├── assets/
│   └── images/                # Aset gambar lokal produk & logo
├── lib/
│   ├── data/
│   │   └── product_data.dart  # Sumber data katalog produk
│   ├── models/
│   │   └── product.dart       # Model data produk
│   ├── screens/               # Kumpulan layar aplikasi
│   ├── theme/                 # Token desain warna, tipografi, dan tema
│   ├── widgets/               # Komponen UI modular (BounceButton, Card, dll)
│   └── main.dart              # Titik masuk utama aplikasi
├── pubspec.yaml               # Konfigurasi dependensi dan aset
└── analysis_options.yaml      # Aturan analisis statis kode
```

## Catatan Pengembangan

- Seluruh data produk dikelola secara lokal pada `lib/data/product_data.dart`.
- Tipografi utama menggunakan **Plus Jakarta Sans** untuk judul/harga dan **Roboto** untuk teks isi (*body*).
- Desain tombol interaktif telah dilengkapi efek pantulan taktil (*BounceButton*) untuk kenyamanan navigasi pengguna.
