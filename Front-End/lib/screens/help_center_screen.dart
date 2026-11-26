import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'support_chat_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({
    super.key,
    this.isLoggedIn = false,
    this.onSignInRequired,
  });

  final bool isLoggedIn;
  final VoidCallback? onSignInRequired;

  void _openChat(BuildContext context) {
    if (!isLoggedIn) {
      onSignInRequired?.call();
      return;
    }

    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi akun berakhir. Masuk kembali untuk chat.'),
        ),
      );
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SupportChatScreen(
          customerId: user.id,
          conversationTitle: 'Admin TokoKita',
          isAdmin: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {
        'q': 'Bagaimana cara melihat status pesanan?',
        'a':
            'Buka Profil, pilih Riwayat Pesanan, lalu pilih pesanan yang ingin Anda lihat. Nomor resi akan muncul setelah toko mengirim pesanan.',
      },
      {
        'q': 'Metode pembayaran apa saja yang tersedia?',
        'a':
            'Metode digital yang diaktifkan untuk toko akan ditampilkan oleh Midtrans saat checkout. COD atau pembayaran di toko hanya tersedia untuk cara penerimaan pesanan yang sesuai.',
      },
      {
        'q': 'Apa yang harus saya lakukan jika barang bermasalah?',
        'a':
            'Hubungi admin toko dengan menyertakan nomor pesanan dan foto barang agar kami bisa membantu memeriksanya.',
      },
      {
        'q': 'Bagaimana memastikan produk yang dipilih sesuai?',
        'a':
            'Periksa deskripsi, ukuran, dan warna pada halaman produk sebelum checkout. Jika ada informasi yang belum jelas, tanyakan kepada admin toko.',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Pusat Bantuan',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perlu bantuan?',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Temukan jawaban seputar pesanan dan pembayaran di bawah ini.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openChat(context),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chat dengan admin',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isLoggedIn
                                ? 'Tanyakan soal produk, pesanan, atau pembayaran.'
                                : 'Masuk untuk memulai percakapan dengan tim kami.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pertanyaan yang sering ditanyakan',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...faqs.map(
            (faq) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: ExpansionTile(
                title: Text(
                  faq['q']!,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      faq['a']!,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
