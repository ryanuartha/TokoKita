import 'package:material_ui/material_ui.dart';

import '../services/customer_address_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';
import 'map_address_picker_screen.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  List<CustomerAddress> _addresses = const [];
  CustomerAddress? _previousOrderAddress;
  bool _isLoading = true;
  String? _loadError;

  List<CustomerAddress> get _displayAddresses => _addresses.isNotEmpty
      ? _addresses
      : _previousOrderAddress == null
      ? const []
      : [_previousOrderAddress!];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final addresses = await CustomerAddressService.loadAddresses();
      final previousOrderAddress = addresses.isEmpty
          ? await CustomerAddressService.loadAddressFromLatestOrder()
          : null;
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _previousOrderAddress = previousOrderAddress;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _setDefaultAddress(CustomerAddress address) async {
    if (address.id == null) return;
    try {
      await CustomerAddressService.setDefaultAddress(address.id!);
      await _loadAddresses();
      if (mounted) _showSnackBar('Alamat utama berhasil diubah.');
    } catch (error) {
      if (mounted) _showSnackBar('Alamat utama belum berhasil diubah: $error');
    }
  }

  Future<void> _savePreviousOrderAddress(CustomerAddress address) async {
    try {
      await CustomerAddressService.saveAddress(
        label: 'Alamat pengiriman',
        recipientName: address.recipientName,
        phone: address.phone,
        address: address.address,
        latitude: address.latitude,
        longitude: address.longitude,
        makeDefault: true,
      );
      await _loadAddresses();
      if (mounted) {
        _showSnackBar('Alamat dari pesanan terakhir berhasil disimpan.');
      }
    } catch (error) {
      if (mounted) _showSnackBar('Alamat belum berhasil disimpan: $error');
    }
  }

  void _showAddAddressSheet() {
    final labelController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    MapAddressSelection? selection;
    var isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom +
                MediaQuery.of(sheetContext).padding.bottom +
                20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tambah Alamat Baru',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _AddressTextField(
                  controller: labelController,
                  label: 'Nama alamat (misalnya, Rumah atau Kantor)',
                ),
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: nameController,
                  label: 'Nama Penerima',
                ),
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: phoneController,
                  label: 'Nomor Telepon',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: addressController,
                  label: 'Alamat lengkap',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final updatedSelection = await showMapAddressPicker(
                      sheetContext,
                      initialSelection: selection,
                      initialAddress: addressController.text,
                    );
                    if (!sheetContext.mounted || updatedSelection == null) {
                      return;
                    }
                    setSheetState(() {
                      selection = updatedSelection;
                      addressController.text = updatedSelection.address;
                    });
                  },
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(
                    selection == null
                        ? 'Pilih titik di peta (opsional)'
                        : 'Titik lokasi dipilih',
                  ),
                ),
                const SizedBox(height: 16),
                BounceButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (labelController.text.trim().isEmpty ||
                              nameController.text.trim().isEmpty ||
                              addressController.text.trim().length < 8) {
                            _showSnackBar(
                              'Isi nama alamat, nama penerima, dan alamat lengkap.',
                            );
                            return;
                          }
                          setSheetState(() => isSaving = true);
                          try {
                            await CustomerAddressService.saveAddress(
                              label: labelController.text,
                              recipientName: nameController.text,
                              phone: phoneController.text,
                              address: addressController.text,
                              latitude: selection?.latitude,
                              longitude: selection?.longitude,
                              makeDefault: _addresses.isEmpty,
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.pop(sheetContext);
                            await _loadAddresses();
                            if (mounted) {
                              _showSnackBar('Alamat berhasil disimpan.');
                            }
                          } catch (error) {
                            if (!sheetContext.mounted) return;
                            setSheetState(() => isSaving = false);
                            _showSnackBar(
                              'Alamat belum berhasil disimpan: $error',
                            );
                          }
                        },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isSaving ? 'Menyimpan...' : 'Simpan Alamat',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      labelController.dispose();
      nameController.dispose();
      phoneController.dispose();
      addressController.dispose();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Alamat Pengiriman',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.coralRed,
              ),
              const SizedBox(height: 12),
              const Text(
                'Alamat belum dapat dimuat.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadAddresses,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _displayAddresses.length + (_displayAddresses.isEmpty ? 2 : 1),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (_displayAddresses.isEmpty && index == 0) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 44,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  'Belum ada alamat tersimpan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Tambahkan alamat sendiri agar dapat digunakan saat checkout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        if (index >=
            _displayAddresses.length + (_displayAddresses.isEmpty ? 1 : 0)) {
          return OutlinedButton.icon(
            onPressed: _showAddAddressSheet,
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            label: const Text(
              'Tambah Alamat Baru',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          );
        }

        return _buildAddressCard(_displayAddresses[index]);
      },
    );
  }

  Widget _buildAddressCard(CustomerAddress address) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.isDefault ? AppColors.primary : AppColors.border,
          width: address.isDefault ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  address.label,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (address.isFromPreviousOrder)
                TextButton(
                  onPressed: () => _savePreviousOrderAddress(address),
                  child: const Text('Simpan alamat'),
                )
              else if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Utama',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () => _setDefaultAddress(address),
                  child: const Text('Atur Utama'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (address.isFromPreviousOrder) ...[
            const Text(
              'Diambil dari pesanan terakhir, belum tersimpan',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            '${address.recipientName} • ${address.phone}',
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            address.address,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (address.latitude != null && address.longitude != null) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Titik lokasi tersimpan',
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressTextField extends StatelessWidget {
  const _AddressTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
