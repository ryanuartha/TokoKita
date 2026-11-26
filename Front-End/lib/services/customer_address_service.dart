import 'auth_service.dart';

class CustomerAddress {
  const CustomerAddress({
    this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.address,
    this.latitude,
    this.longitude,
    required this.isDefault,
    this.isFromPreviousOrder = false,
  });

  final String? id;
  final String label;
  final String recipientName;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final bool isFromPreviousOrder;

  factory CustomerAddress.fromMap(Map<String, dynamic> row) {
    return CustomerAddress(
      id: row['id'] as String,
      label: row['label'] as String,
      recipientName: row['recipient_name'] as String,
      phone: row['phone'] as String? ?? '',
      address: row['address'] as String,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      isDefault: row['is_default'] as bool,
    );
  }
}

class CustomerAddressService {
  static Future<List<CustomerAddress>> loadAddresses() async {
    final rows = await AuthService.client
        .from('customer_addresses')
        .select(
          'id, label, recipient_name, phone, address, latitude, longitude, is_default',
        )
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);

    return rows.map((row) => CustomerAddress.fromMap(row)).toList();
  }

  static Future<CustomerAddress?> loadPreferredAddress() async {
    final addresses = await loadAddresses();
    if (addresses.isNotEmpty) {
      for (final address in addresses) {
        if (address.isDefault) return address;
      }
      return addresses.first;
    }

    return loadAddressFromLatestOrder();
  }

  static Future<CustomerAddress?> loadAddressFromLatestOrder() async {
    final row = await AuthService.client
        .from('orders')
        .select('shipping_address, shipping_latitude, shipping_longitude')
        .eq('fulfillment_method', 'courier')
        .neq('shipping_address', '')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    final address = row['shipping_address'] as String? ?? '';
    if (address.trim().isEmpty) return null;

    final user = AuthService.currentUser;
    final metadataName = user?.userMetadata?['full_name'] as String?;
    final metadataPhone = user?.userMetadata?['phone'] as String?;
    return CustomerAddress(
      label: 'Alamat pesanan terakhir',
      recipientName: metadataName?.trim().isNotEmpty == true
          ? metadataName!.trim()
          : user?.email?.split('@').first ?? 'Pengguna TokoKita',
      phone: metadataPhone?.trim() ?? '',
      address: address,
      latitude: (row['shipping_latitude'] as num?)?.toDouble(),
      longitude: (row['shipping_longitude'] as num?)?.toDouble(),
      isDefault: false,
      isFromPreviousOrder: true,
    );
  }

  static Future<void> saveAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String address,
    double? latitude,
    double? longitude,
    bool makeDefault = false,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('Masuk ke akun terlebih dahulu untuk menyimpan alamat.');
    }

    final existingAddresses = await loadAddresses();
    final row = await AuthService.client
        .from('customer_addresses')
        .insert({
          'user_id': user.id,
          'label': label.trim(),
          'recipient_name': recipientName.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'is_default': false,
        })
        .select('id')
        .single();

    final id = row['id'] as String;
    if (makeDefault || existingAddresses.isEmpty) {
      await setDefaultAddress(id);
    }
  }

  static Future<void> saveCheckoutAddress({
    required String recipientName,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('Masuk ke akun terlebih dahulu untuk menyimpan alamat.');
    }

    final addresses = await loadAddresses();
    CustomerAddress? preferred;
    for (final savedAddress in addresses) {
      if (savedAddress.isDefault) {
        preferred = savedAddress;
        break;
      }
    }
    preferred ??= addresses.isEmpty ? null : addresses.first;

    if (preferred == null) {
      await saveAddress(
        label: 'Alamat pengiriman',
        recipientName: recipientName,
        phone: user.userMetadata?['phone'] as String? ?? '',
        address: address,
        latitude: latitude,
        longitude: longitude,
        makeDefault: true,
      );
      return;
    }

    final updated = await AuthService.client
        .from('customer_addresses')
        .update({
          'recipient_name': recipientName.trim(),
          'address': address.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', preferred.id!)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Alamat tidak ditemukan. Muat ulang lalu coba lagi.');
    }

    if (!preferred.isDefault) {
      await setDefaultAddress(preferred.id!);
    }
  }

  static Future<void> setDefaultAddress(String addressId) async {
    await AuthService.client.rpc(
      'set_default_customer_address',
      params: {'p_address_id': addressId},
    );
  }
}
