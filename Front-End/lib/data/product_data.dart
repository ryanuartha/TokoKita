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
    description: 'Smartphone 5G dengan layar AMOLED 120 Hz.',
    detailDescription:
        'Nova X Pro 5G memiliki layar AMOLED 120 Hz dan mendukung pengisian '
        'daya cepat 67 W. Cocok untuk digunakan sehari-hari.',
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
    description: 'Headphone nirkabel dengan peredam bising aktif (ANC).',
    detailDescription:
        'Headphone Studio Wireless memiliki fitur peredam bising aktif (ANC) '
        'dan bantalan telinga empuk untuk mendengarkan musik atau mengikuti rapat.',
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
    description: 'Smartwatch dengan pemantau detak jantung dan tidur.',
    detailDescription:
        'Fit Active GT dilengkapi sensor detak jantung, pelacak tidur, dan beberapa '
        'mode olahraga. Jam ini tahan air hingga kedalaman 50 meter.',
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
    description: 'Speaker Bluetooth portabel dengan baterai hingga 12 jam.',
    detailDescription:
        'Speaker Mini Portable Bass+ mudah dibawa dan menghasilkan suara stereo. '
        'Baterainya dapat digunakan hingga 12 jam pemutaran.',
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
    description: 'Tablet dengan layar 2K untuk bekerja dan menikmati hiburan.',
    detailDescription:
        'Tablet Ultra Pad Pro memiliki layar 2K untuk menonton, menggambar, atau '
        'menggunakan beberapa aplikasi sekaligus.',
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
    description: 'Earbuds nirkabel dengan peredam bising dan Bluetooth 5.3.',
    detailDescription:
        'Earbuds TWS Pro menggunakan Bluetooth 5.3 dan dilengkapi mikrofon '
        'untuk panggilan telepon.',
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
    description: 'Hoodie fleece berbahan katun yang lembut dan hangat.',
    detailDescription:
        'Hoodie Classic Fleece memiliki potongan santai dan bahan katun fleece '
        'yang lembut untuk menemani aktivitas sehari-hari.',
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
    description: 'Kaos polos berbahan katun yang nyaman untuk dipakai sehari-hari.',
    detailDescription:
        'Kaos Basic Cotton Combed 24s memiliki jahitan rapi dan bahan yang '
        'menyerap keringat. Cocok untuk pakaian sehari-hari.',
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
    description: 'Jaket kasual dengan lapisan dalam dan saku beritsleting.',
    detailDescription:
        'Jaket Urban memiliki saku beritsleting dan lapisan dalam yang nyaman. '
        'Bisa digunakan saat berkendara atau beraktivitas di luar ruangan.',
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
    description: 'Sneakers dengan bantalan fleksibel untuk aktivitas sehari-hari.',
    detailDescription:
        'Daily Comfort Runner memiliki sol fleksibel dan antiselip untuk membantu '
        'menjaga langkah tetap nyaman.',
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
    description: 'Kemeja linen untuk acara santai atau semi-formal.',
    detailDescription:
        'Kemeja Linen Slim Fit memiliki potongan ramping dan bahan linen yang '
        'nyaman dipakai dalam cuaca hangat.',
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
    description: 'Celana chino berbahan katun twill elastis.',
    detailDescription:
        'Celana Chino Stretch menggunakan bahan katun twill elastis agar nyaman '
        'dipakai bekerja maupun bersantai.',
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
    description: 'Kacamata hitam polarized dengan perlindungan UV400.',
    detailDescription:
        'Lensa polarized membantu mengurangi silau. Kacamata ini memiliki '
        'perlindungan UV400 dan bingkai logam yang ringan.',
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
    description: 'Ransel 20 liter dengan kompartemen laptop 15,6 inci.',
    detailDescription:
        'Ransel Laptop menggunakan bahan nilon yang tahan percikan air. '
        'Tersedia bantalan punggung, port USB, dan beberapa kantong penyimpanan.',
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
    description: 'Dompet lipat dengan slot kartu dan lapisan pelindung RFID.',
    detailDescription:
        'Dompet Genuine Bifold memiliki tekstur kulit dan beberapa slot kartu. '
        'Lapisan RFID membantu melindungi kartu dari pemindaian tanpa izin.',
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
    description: 'Jam tangan analog dengan desain sederhana dan tali kulit.',
    detailDescription:
        'Jam tangan ini menggunakan mesin quartz dan memiliki ketahanan air. '
        'Desainnya cocok dipadukan dengan pakaian sehari-hari.',
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
    description: 'Topi baseball berbahan kanvas dengan tali pengatur ukuran.',
    detailDescription:
        'Topi baseball ini berbahan kanvas dan memiliki tali pengatur ukuran. '
        'Bordir sederhana membuatnya mudah dipadukan dengan pakaian kasual.',
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
    description: 'Botol minum stainless steel untuk minuman panas atau dingin.',
    detailDescription:
        'Botol ini menggunakan stainless steel SUS 304 dan dinding ganda berinsulasi '
        'vakum untuk membantu menjaga suhu minuman.',
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
