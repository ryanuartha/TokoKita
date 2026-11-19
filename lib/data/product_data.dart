import '../models/product.dart';

const List<Product> products = [
  // ==========================================
  // KATEGORI 1: ELEKTRONIK (6 PRODUK)
  // ==========================================
  Product(
    id: 'EL-001',
    name: 'Smartphone Nova X Pro 5G',
    category: 'Elektronik',
    imageAsset: 'assets/images/el_001.jpg',
    description: 'Smartphone berperforma tinggi dengan layar AMOLED 120Hz.',
    detailDescription:
        'Smartphone Nova X Pro 5G dirancang untuk mendukung aktivitas harian, '
        'gaming, dan fotografi profesional. Dibekali baterai tahan lama serta pengisian '
        'daya cepat 67W, perangkat ini siap menemani mobilitas Anda sepanjang hari.',
    price: 3499000,
    originalPrice: 4299000,
    rating: 4.9,
    reviewCount: 328,
    soldCount: 1450,
    badge: 'Terlaris',
  ),
  Product(
    id: 'EL-002',
    name: 'Headphone Studio Wireless',
    category: 'Elektronik',
    imageAsset: 'assets/images/el_002.jpg',
    description: 'Headphone over-ear nyaman dengan bass mendalam.',
    detailDescription:
        'Headphone Studio Wireless menyajikan kualitas audio jernih dan fitur peredam '
        'bising aktif (ANC). Bantalan telinga empuk membuat Anda nyaman mendengarkan musik '
        'atau mengikuti rapat online berjam-jam.',
    price: 899000,
    originalPrice: 1199000,
    rating: 4.8,
    reviewCount: 194,
    soldCount: 820,
    badge: 'Diskon 25%',
  ),
  Product(
    id: 'EL-003',
    name: 'Smartwatch Fit Active GT',
    category: 'Elektronik',
    imageAsset: 'assets/images/el_003.jpg',
    description: 'Jam tangan pintar pemantau kebugaran & kesehatan 24 jam.',
    detailDescription:
        'Smartwatch Fit Active GT hadir dengan sensor detak jantung akurat, pelacak tidur, '
        'serta mode olahraga lengkap. Desainnya minimalis dan tahan air hingga kedalaman 50 meter.',
    price: 1299000,
    originalPrice: 1599000,
    rating: 4.7,
    reviewCount: 142,
    soldCount: 650,
    badge: 'Pilihan',
  ),
  Product(
    id: 'EL-004',
    name: 'Speaker Mini Portable Bass+',
    category: 'Elektronik',
    imageAsset: 'assets/images/el_004.jpg',
    description: 'Speaker Bluetooth ringkas dengan suara bertenaga.',
    detailDescription:
        'Speaker Mini Portable Bass+ mudah dibawa bepergian dan menghasilkan suara '
        'stereo yang jernih dengan dentuman bass solid. Baterai tahan hingga 12 jam pemutaran.',
    price: 450000,
    originalPrice: 550000,
    rating: 4.6,
    reviewCount: 88,
    soldCount: 410,
    badge: 'Official',
  ),
  Product(
    id: 'EL-005',
    name: 'Tablet Ultra Pad Pro 11"',
    category: 'Elektronik',
    imageAsset: 'assets/images/el_005.jpg',
    description: 'Tablet layar lebar untuk kerja produktif dan hiburan.',
    detailDescription:
        'Tablet Ultra Pad Pro memiliki layar 2K tajam dan responsif, sangat ideal untuk '
        'menonton film, menggambar, maupun multitasking aplikasi produktivitas tinggi.',
    price: 4899000,
    originalPrice: 5999000,
    rating: 4.9,
    reviewCount: 215,
    soldCount: 540,
    badge: 'Flagship',
  ),
  Product(
    id: 'EL-006',
    name: 'Earbuds True Wireless ANC Pro',
    category: 'Elektronik',
    imageAsset: 'assets/images/el_006.jpg',
    description: 'Earbuds nirkabel jernih dengan fitur anti bising.',
    detailDescription:
        'Earbuds TWS Pro memberikan kebebasan menikmati audio bebas kabel. '
        'Koneksi Bluetooth 5.3 ultra stabil dan mikrofon jernih untuk panggilan telepon.',
    price: 599000,
    originalPrice: 799000,
    rating: 4.7,
    reviewCount: 310,
    soldCount: 1890,
    badge: 'Populer',
  ),

  // ==========================================
  // KATEGORI 2: PAKAIAN (6 PRODUK)
  // ==========================================
  Product(
    id: 'PK-001',
    name: 'Hoodie Classic Fleece Premium',
    category: 'Pakaian',
    imageAsset: 'assets/images/pk_001.jpg',
    description: 'Hoodie katun fleece hangat dan lembut di kulit.',
    detailDescription:
        'Hoodie Classic Fleece dirancang dengan potongan modern yang santai. '
        'Bahan katun fleece lembut berkualitas menjaga tubuh tetap hangat di cuaca dingin.',
    price: 249000,
    originalPrice: 320000,
    rating: 4.9,
    reviewCount: 512,
    soldCount: 2300,
    badge: 'Terlaris',
  ),
  Product(
    id: 'PK-002',
    name: 'Kaos Basic Heavyweight Cotton',
    category: 'Pakaian',
    imageAsset: 'assets/images/pk_002.jpg',
    description: 'Kaos polos katun premium yang adem dan tidak mudah melar.',
    detailDescription:
        'Kaos Basic Cotton Combed 24s dengan jahitan rapi dan daya serap keringat yang maksimal. '
        'Pilihan terbaik untuk outfit kasual harian Anda.',
    price: 89000,
    originalPrice: 125000,
    rating: 4.8,
    reviewCount: 640,
    soldCount: 3100,
    badge: 'Diskon 28%',
  ),
  Product(
    id: 'PK-003',
    name: 'Jaket Urban Windproof Outer',
    category: 'Pakaian',
    imageAsset: 'assets/images/pk_003.jpg',
    description: 'Jaket kasual tahan angin untuk aktivitas luar ruangan.',
    detailDescription:
        'Jaket Urban melindungi tubuh dari hembusan angin dingin saat berkendara motor. '
        'Dilengkapi saku fungsional beritsleting dan lapisan dalam yang nyaman.',
    price: 379000,
    originalPrice: 480000,
    rating: 4.9,
    reviewCount: 156,
    soldCount: 780,
    badge: 'Baru',
  ),
  Product(
    id: 'PK-004',
    name: 'Sneakers Daily Comfort Runner',
    category: 'Pakaian',
    imageAsset: 'assets/images/pk_004.jpg',
    description: 'Sepatu sneakers sport merah empuk untuk aktivitas harian.',
    detailDescription:
        'Sneakers Daily Comfort Runner mengusung bantalan sol fleksibel anti-slip. '
        'Membuat langkah Anda ringan dan nyaman seharian tanpa membuat kaki cepat lelah.',
    price: 499000,
    originalPrice: 650000,
    rating: 4.8,
    reviewCount: 284,
    soldCount: 1290,
    badge: 'Favorit',
  ),
  Product(
    id: 'PK-005',
    name: 'Kemeja Linen Slim Fit Casual',
    category: 'Pakaian',
    imageAsset: 'assets/images/pk_005.jpg',
    description: 'Kemeja linen adem untuk acara santai maupun semi-formal.',
    detailDescription:
        'Kemeja Linen Slim Fit memberikan tampilan rapi namun tetap santai. '
        'Terbuat dari serat linen alami yang sangat adem dan nyaman digunakan di iklim tropis.',
    price: 199000,
    originalPrice: 260000,
    rating: 4.7,
    reviewCount: 188,
    soldCount: 850,
    badge: 'Elegan',
  ),
  Product(
    id: 'PK-006',
    name: 'Celana Chino Stretch Workwear',
    category: 'Pakaian',
    imageAsset: 'assets/images/pk_006.jpg',
    description: 'Celana chino panjang fleksibel untuk kerja dan kuliah.',
    detailDescription:
        'Celana Chino Stretch dibuat dari katun twill elastis berkualitas tinggi. '
        'Menyajikan fleksibilitas kebebasan bergerak penuh untuk aktivitas bekerja maupun santai.',
    price: 229000,
    originalPrice: 299000,
    rating: 4.8,
    reviewCount: 340,
    soldCount: 1620,
    badge: 'Top',
  ),

  // ==========================================
  // KATEGORI 3: AKSESORI (6 PRODUK)
  // ==========================================
  Product(
    id: 'AK-001',
    name: 'Kacamata Polarized Aviator HD',
    category: 'Aksesori',
    imageAsset: 'assets/images/ak_001.jpg',
    description: 'Kacamata hitam anti silau dengan perlindungan UV400.',
    detailDescription:
        'Kacamata Polarized Aviator melindungi mata dari terik sinar matahari dan silau. '
        'Bingkai logam ringan yang kokoh dan nyaman dipakai saat berkendara.',
    price: 179000,
    originalPrice: 250000,
    rating: 4.9,
    reviewCount: 275,
    soldCount: 1420,
    badge: 'Terlaris',
  ),
  Product(
    id: 'AK-002',
    name: 'Ransel Laptop Waterproof 20L',
    category: 'Aksesori',
    imageAsset: 'assets/images/ak_002.jpg',
    description:
        'Tas ransel punggung tahan air dengan kompartemen laptop 15.6".',
    detailDescription:
        'Ransel Laptop terbuat dari bahan boks nilon tahan percikan air. '
        'Dilengkapi bantalan punggung ergonomis, port USB charger, dan banyak kantong penyimpanan.',
    price: 329000,
    originalPrice: 420000,
    rating: 4.8,
    reviewCount: 480,
    soldCount: 2350,
    badge: 'Andalan',
  ),
  Product(
    id: 'AK-003',
    name: 'Dompet Kulit Genuine Bifold',
    category: 'Aksesori',
    imageAsset: 'assets/images/ak_003.jpg',
    description: 'Dompet lipat kulit sapi asli dengan proteksi kartu RFID.',
    detailDescription:
        'Dompet kulit sapi asli dengan tekstur alami yang elegan dan awet bertahun-tahun. '
        'Dilengkapi slot kartu presisi serta lapisan anti-skimming RFID.',
    price: 159000,
    originalPrice: 210000,
    rating: 4.9,
    reviewCount: 390,
    soldCount: 1980,
    badge: 'Kulit',
  ),
  Product(
    id: 'AK-004',
    name: 'Jam Tangan Analog Minimalis',
    category: 'Aksesori',
    imageAsset: 'assets/images/ak_004.jpg',
    description: 'Jam tangan pria berdesain klasik dengan tali kulit presisi.',
    detailDescription:
        'Jam tangan analog berdesain simpel dan mewah. Menghadirkan ketahanan air (water resistant) '
        'serta mesin Quartz akurat untuk melengkapi gaya berbusana Anda.',
    price: 489000,
    originalPrice: 650000,
    rating: 4.8,
    reviewCount: 160,
    soldCount: 740,
    badge: 'Elegan',
  ),
  Product(
    id: 'AK-005',
    name: 'Topi Baseball Canvas Vintage',
    category: 'Aksesori',
    imageAsset: 'assets/images/ak_005.jpg',
    description: 'Topi kasual bahan kanvas dengan pengatur lingkar kepala.',
    detailDescription:
        'Topi baseball berbahan kanvas lembut yang nyaman melindungi wajah dari sinar matahari. '
        'Desain bordir simpel cocok untuk padanan gaya santai harian.',
    price: 69000,
    originalPrice: 99000,
    rating: 4.7,
    reviewCount: 530,
    soldCount: 2890,
    badge: 'Diskon 30%',
  ),
  Product(
    id: 'AK-006',
    name: 'Botol Minum Stainless Thermal',
    category: 'Aksesori',
    imageAsset: 'assets/images/ak_006.jpg',
    description: 'Tumbler termos tahan suhu panas dan dingin hingga 12 jam.',
    detailDescription:
        'Botol minum dari material Stainless Steel SUS 304 food-grade anti karat. '
        'Dinding ganda berinsulasi vakum menjaga kesegaran minuman favorit Anda sepanjang hari.',
    price: 139000,
    originalPrice: 189000,
    rating: 4.9,
    reviewCount: 420,
    soldCount: 2600,
    badge: 'Eco',
  ),
];

const List<String> productCategories = [
  'Semua',
  'Elektronik',
  'Pakaian',
  'Aksesori',
];
