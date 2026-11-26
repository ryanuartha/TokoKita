import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

class MapAddressSelection {
  const MapAddressSelection({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}

Future<MapAddressSelection?> showMapAddressPicker(
  BuildContext context, {
  MapAddressSelection? initialSelection,
  String initialAddress = '',
}) {
  return Navigator.of(context).push<MapAddressSelection>(
    MaterialPageRoute<MapAddressSelection>(
      builder: (_) => MapAddressPickerScreen(
        initialSelection: initialSelection,
        initialAddress: initialAddress,
      ),
    ),
  );
}

class MapAddressPickerScreen extends StatefulWidget {
  const MapAddressPickerScreen({
    super.key,
    this.initialSelection,
    this.initialAddress = '',
  });

  final MapAddressSelection? initialSelection;
  final String initialAddress;

  @override
  State<MapAddressPickerScreen> createState() => _MapAddressPickerScreenState();
}

class _MapAddressPickerScreenState extends State<MapAddressPickerScreen> {
  static const _defaultCenter = LatLng(-7.7956, 110.3695);
  static const _tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  late final TextEditingController _addressController;
  LatLng? _selectedPoint;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelection;
    _addressController = TextEditingController(
      text: initial?.address ?? widget.initialAddress,
    );
    if (initial != null) {
      _selectedPoint = LatLng(initial.latitude, initial.longitude);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _saveSelection() {
    final point = _selectedPoint;
    final address = _addressController.text.trim();
    if (point == null || address.length < 8) return;

    Navigator.pop(
      context,
      MapAddressSelection(
        address: address,
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = _selectedPoint;
    final canSave = point != null && _addressController.text.trim().length >= 8;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pilih titik alamat'),
        backgroundColor: AppColors.cardSurface,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point ?? _defaultCenter,
                initialZoom: point == null ? 12 : 16,
                onTap: (_, selectedPoint) {
                  setState(() => _selectedPoint = selectedPoint);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrlTemplate,
                  userAgentPackageName: 'id.tokokita.app',
                ),
                if (point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        alignment: Alignment.bottomCenter,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    point == null
                        ? 'Ketuk peta untuk meletakkan pin di lokasi tujuan.'
                        : 'Titik: ${point.latitude.toStringAsFixed(6)}, '
                              '${point.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Alamat lengkap',
                      hintText: 'Jalan, nomor rumah, kelurahan, dan kota',
                      filled: true,
                      fillColor: AppColors.cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Peta memakai OpenStreetMap; alamat diisi manual. Untuk '
                    'akun yang masuk, alamat pilihan tersimpan untuk checkout '
                    'berikutnya.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: canSave ? _saveSelection : null,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Gunakan titik dan alamat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
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
