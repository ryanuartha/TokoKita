import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/support_chat_service.dart';
import '../theme/app_colors.dart';
import 'support_chat_screen.dart';

class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  late Future<List<SupportConversation>> _conversationsFuture;
  RealtimeChannel? _inboxChannel;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = SupportChatService.loadConversations();
    final adminId = AuthService.currentUser?.id;
    if (adminId != null) {
      _inboxChannel = AuthService.client
          .channel('support-inbox-$adminId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_messages',
            callback: (_) => _reload(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    final channel = _inboxChannel;
    if (channel != null) {
      unawaited(AuthService.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = SupportChatService.loadConversations();
    setState(() => _conversationsFuture = future);
    await future;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _conversationsFuture = SupportChatService.loadConversations();
    });
  }

  Future<void> _openConversation(SupportConversation conversation) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SupportChatScreen(
          customerId: conversation.customerId,
          conversationTitle: conversation.customerName,
          isAdmin: true,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupportConversation>>(
      future: _conversationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.textMuted,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kotak chat belum bisa dimuat.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final conversations = snapshot.data ?? const [];
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'Kotak masuk',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Balas pertanyaan pembeli secara langsung.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (conversations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 72),
                  child: Column(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        color: AppColors.textMuted,
                        size: 44,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Belum ada percakapan',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pesan dari pembeli akan muncul di sini.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...conversations.map(
                  (conversation) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _openConversation(conversation),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.accentSoft,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        conversation.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          conversation.senderId == AuthService.currentUser?.id
                              ? 'Anda: ${conversation.lastMessage}'
                              : conversation.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      trailing: Text(
                        _formatDate(conversation.lastMessageAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
}
