# Back-End TokoKita

Back-end memakai Supabase Auth, Postgres dengan Row Level Security, Edge
Functions, dan Midtrans Snap. Struktur implementasi:

```text
supabase/
├── config.toml
├── migrations/       # profil, katalog, pesanan, stok, RLS, dan RPC
└── functions/
    ├── create-payment/
    ├── midtrans-webhook/
    ├── order-action/
    └── delete-account/
```

## Konfigurasi aplikasi Flutter

Salin `Front-End/config/local.example.json` menjadi
`Front-End/config/local.json` dan isi `SUPABASE_URL` serta
`SUPABASE_ANON_KEY` dengan nilai publik proyek Supabase. Jangan pernah
menaruh service-role key atau Midtrans Server Key di aplikasi Flutter.

Jalankan dari folder `Front-End`:

```bash
flutter run --dart-define-from-file=config/local.json
```

## Konfirmasi email di Android

Pendaftaran mengarahkan tautan konfirmasi ke
`id.tokokita.app://auth-callback`, yang akan membuka aplikasi dan membuat sesi
login setelah email dikonfirmasi. Tambahkan URL yang sama persis ke Supabase
Dashboard → Authentication → URL Configuration → Additional Redirect URLs.

Redirect ini digunakan khusus untuk konfirmasi pendaftaran. Tautan konfirmasi
yang sudah dikirim sebelumnya masih memakai alamat lama; kirim ulang email
konfirmasi atau gunakan pendaftaran baru saat menguji.

## Titik alamat pengiriman

Checkout memakai peta OpenStreetMap tanpa Google Maps API key. Pembeli
meletakkan pin, lalu mengisi alamat lengkap secara manual; alamat dan koordinat
disimpan pada pesanan di Supabase. Koordinat tidak dikirim ke layanan
reverse-geocoding publik. Peta menampilkan atribusi OpenStreetMap dan memakai
tile cache bawaan `flutter_map`.

Tile publik OpenStreetMap bersifat best-effort dan tidak memiliki jaminan
layanan. Patuhi [kebijakan penggunaan tile OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/)
dan pertimbangkan penyedia tile khusus jika volume aplikasi meningkat.

## Deploy Supabase

Pasang Supabase CLI, lalu dari folder `Back-End` jalankan:

```bash
supabase login
supabase link --project-ref PROJECT_REF
supabase db push
```

Migration `20261126060000_shipping_coordinates.sql` menambahkan koordinat
pengiriman. Terapkan migration sebelum memasang versi aplikasi Flutter terbaru.
Migration `20261126100000_admin_inventory_management.sql` mengaktifkan daftar
produk admin dan pembaruan kolom stok; akses baca seluruh produk dan perubahan
stok dibatasi untuk akun admin terautentikasi.
Migration `20261126110000_order_item_variants.sql` menyimpan ukuran dan warna
pilihan pada setiap item pesanan. Setelah `supabase db push`, deploy ulang
fungsi `create-payment`. Stok tetap divalidasi pada tingkat produk, bukan
dipisahkan per ukuran atau warna.

## Chat pembeli dan admin

Pembeli yang sudah masuk dapat membuka chat melalui Pusat Bantuan. Admin
membalas percakapan dari tab **Chat** di dashboard admin. Pesan teks disimpan
di `public.support_messages` dan diperbarui secara langsung melalui Supabase
Realtime; Row Level Security membatasi pembeli ke percakapannya sendiri dan
admin ke percakapan dukungan.

Terapkan migration `20261126070000_support_chat.sql` dengan `supabase db push`
sebelum menggunakan fitur ini. Riwayat chat milik pelanggan ikut dihapus saat
akun pelanggan dihapus. Chat saat ini hanya mendukung pesan teks hingga 2.000
karakter.

Sebelum menerima pesanan, atur stok di tabel `public.products` sesuai jumlah
barang nyata yang tersedia. Migration mengisi produk katalog dengan stok `0`
agar tidak menjual inventaris yang belum diverifikasi.

Simpan rahasia Midtrans pada file lokal `Back-End/.env.local` (file ini
diabaikan Git):

```dotenv
MIDTRANS_SERVER_KEY=ISI_SERVER_KEY_DI_MESIN_LOKAL
MIDTRANS_IS_PRODUCTION=false
```

Gunakan Server Key Sandbox untuk pengujian. Dari folder `Back-End`, unggah
secrets dan deploy fungsi:

```bash
supabase secrets set --env-file .env.local
supabase functions deploy create-payment
supabase functions deploy order-action
supabase functions deploy delete-account
supabase functions deploy midtrans-webhook
```

Penghapusan akun hanya tersedia untuk akun pelanggan. Password diverifikasi
ulang, pesanan yang belum selesai harus dituntaskan terlebih dahulu, dan
riwayat pesanan selesai/batal tetap disimpan dengan identitas, alamat, dan
koordinat pengiriman dihapus.

Pembeli dapat membatalkan pesanan yang menunggu pembayaran atau pesanan COD /
bayar di toko yang belum dibayar dan belum dikirim. Untuk pembayaran Midtrans,
aplikasi membatalkan transaksi di Midtrans terlebih dahulu sebelum melepas
stok. Pesanan yang sudah dibayar atau dikirim tidak dapat dibatalkan dari
aplikasi.

Di dashboard Midtrans Sandbox, atur Payment Notification URL ke:

```text
https://PROJECT_REF.supabase.co/functions/v1/midtrans-webhook
```

Gunakan URL produksi dan ubah `MIDTRANS_IS_PRODUCTION=true` hanya setelah
pengujian sandbox berhasil dan akun Midtrans siap live.

## Menjadikan akun sebagai admin

Daftarkan akun melalui aplikasi terlebih dahulu. Setelah itu, dari SQL Editor
Supabase ubah role akun secara manual, mengganti alamat email dengan akun
admin yang sudah terdaftar:

```sql
update public.profiles
set role = 'admin'
where id = (
  select id from auth.users where email = 'admin@contoh.id'
);
```

Registrasi publik selalu mendapat role `customer`; nama atau alamat email
pengguna tidak dapat memberikan hak admin.

## Batasan yang perlu dikonfigurasi

- Ongkir saat ini bernilai `0`; aturan alamat, tarif kurir, dan voucher
  gratis ongkir belum ditetapkan.
- Pembayaran COD dicatat sebagai belum diterima sampai admin mengonfirmasinya.
  Pembayaran di toko ditandai lunas saat admin menyerahkan pesanan pickup.
- Pembayaran VA di Snap saat ini mengaktifkan BCA. Metode lain harus diaktifkan
  sesuai kontrak dan pengaturan akun Midtrans.
- Pembayaran berstatus lunas hanya setelah webhook Midtrans terverifikasi.
  Aplikasi membaca ulang status dari Supabase dan tidak dapat menandai transaksi
  sukses secara lokal.
- Email pemulihan kata sandi masih mengikuti URL situs Supabase; deep link
  pemulihan kata sandi belum dikonfigurasi.
- Dashboard admin dapat membaca pesanan, mengelola jumlah stok, dan menampilkan
  ringkasan pembayaran/status pesanan. Laporan ini belum menggantikan sistem
  akuntansi: belum mencakup rekonsiliasi biaya, refund, pajak, atau settlement
  Midtrans.
