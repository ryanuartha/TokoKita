import 'auth_service.dart';

class SupportConversation {
  const SupportConversation({
    required this.customerId,
    required this.customerName,
    required this.lastMessage,
    required this.senderId,
    required this.lastMessageAt,
  });

  final String customerId;
  final String customerName;
  final String lastMessage;
  final String? senderId;
  final DateTime lastMessageAt;
}

class SupportChatService {
  static Stream<List<Map<String, dynamic>>> watchMessages({
    required String customerId,
  }) {
    return AuthService.client
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: true);
  }

  static Future<List<SupportConversation>> loadConversations() async {
    final rows = await AuthService.client
        .from('support_conversations')
        .select(
          'customer_id, customer_name, sender_id, last_message, last_message_at',
        )
        .order('last_message_at', ascending: false);

    return rows
        .map(
          (row) => SupportConversation(
            customerId: row['customer_id'] as String,
            customerName: row['customer_name'] as String,
            senderId: row['sender_id'] as String?,
            lastMessage: row['last_message'] as String,
            lastMessageAt: DateTime.parse(row['last_message_at'] as String),
          ),
        )
        .toList();
  }

  static Future<void> sendMessage({
    required String customerId,
    required String body,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('Masuk ke akun terlebih dahulu untuk mengirim pesan.');
    }

    final message = body.trim();
    if (message.isEmpty || message.length > 2000) {
      throw ArgumentError.value(
        body,
        'body',
        'Pesan harus berisi 1 sampai 2.000 karakter.',
      );
    }

    await AuthService.client.from('support_messages').insert({
      'customer_id': customerId,
      'sender_id': user.id,
      'body': message,
    });
  }
}
