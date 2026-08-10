import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/glass.dart';

/// Экран точной установки метки: двигаем карту под булавку.
class MapPickerScreen extends StatefulWidget {
  final LatLng initial;
  final String address;
  const MapPickerScreen({super.key, required this.initial, this.address = ''});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _controller = MapController();
  // По умолчанию «Схема» (OSM) — русские подписи улиц и быстрая загрузка.
  MapLayer _layer = MapLayer.scheme;
  bool _locating = false;

  /// Переместить карту (а сним и булавку) на текущее местоположение.
  /// Логика разрешений та же, что на основной карте.
  Future<void> _goToMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) await _promptOpenSettings(serviceDisabled: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) await _promptOpenSettings(serviceDisabled: false);
        return;
      }
      if (perm == LocationPermission.denied) {
        _locationFailed();
        return;
      }
      // Быстрый отклик: если есть последнее известное местоположение,
      // сразу двигаем карту к нему — плитки начинают грузиться, пока
      // ждём точную геопозицию (иначе кажется, что «долго грузится»).
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          _controller.move(LatLng(last.latitude, last.longitude), 16);
        }
      } catch (_) {}
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 12));
      setGpsPosition(pos.latitude, pos.longitude);
      if (!mounted) return;
      // Ставим булавку на моё место — булавка привязана к центру карты.
      _controller.move(LatLng(pos.latitude, pos.longitude), 17);
    } catch (_) {
      _locationFailed();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _locationFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Не удалось определить местоположение'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Диалог с предложением открыть системные настройки.
  Future<void> _promptOpenSettings({required bool serviceDisabled}) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(serviceDisabled
            ? 'Геолокация выключена'
            : 'Нет доступа к геолокации'),
        content: Text(serviceDisabled
            ? 'Чтобы поставить метку по своему месту, включите геолокацию (GPS) в настройках телефона.'
            : 'Разрешите приложению доступ к геолокации в настройках телефона.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
    if (open == true) {
      if (serviceDisabled) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Метка на карте',
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 17,
              minZoom: 3,
              maxZoom: 20,
            ),
            children: [
              TileLayer(
                urlTemplate: _layer == MapLayer.scheme
                    ? osmSchemeTileUrl
                    : esriSatelliteTileUrl,
                userAgentPackageName: 'com.shabashka.shabashka_app',
                maxZoom: 19,
                keepBuffer: 3,
                evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
              ),
              // Гибрид: спутник + русская схема OSM полупрозрачно (подписи
              // улиц по-русски, как в Яндекс.Картах). Английские подписи
              // Esri не используем — они давали «Moscow» вместо «Москва».
              if (_layer == MapLayer.hybrid)
                Opacity(
                  opacity: 0.55,
                  child: TileLayer(
                    urlTemplate: osmSchemeTileUrl,
                    userAgentPackageName: 'com.shabashka.shabashka_app',
                    maxZoom: 19,
                    keepBuffer: 3,
                    evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                  ),
                ),
            ],
          ),
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 42),
                child: Icon(Icons.location_on,
                    size: 52, color: Color(0xFFEF4444)),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Двигайте карту так, чтобы булавка указывала на нужный дом',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (widget.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 96,
            child: Column(
              children: [
                // Кнопка «На моё место» — такая же, как на основной карте.
                FloatingActionButton(
                  heroTag: 'pickToMe',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0284C7),
                  onPressed: _locating ? null : _goToMe,
                  child: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zin',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0284C7),
                  onPressed: () {
                    final c = _controller.camera;
                    _controller.move(c.center, c.zoom + 1);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zout',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0284C7),
                  onPressed: () {
                    final c = _controller.camera;
                    _controller.move(c.center, c.zoom - 1);
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          // Переключатель слоёв карты (как на основной карте).
          Positioned(
            left: 12,
            bottom: 96,
            child: _LayerSwitcher(
              current: _layer,
              onChanged: (l) => setState(() => _layer = l),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: BigButton(
              label: 'ПОДТВЕРДИТЬ МЕСТО',
              icon: Icons.check,
              color: AppTheme.primaryColor,
              onPressed: () {
                Navigator.pop(context, _controller.camera.center);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка выбора слоя карты (спутник / схема / гибрид).
class _LayerSwitcher extends StatelessWidget {
  final MapLayer current;
  final ValueChanged<MapLayer> onChanged;
  const _LayerSwitcher({required this.current, required this.onChanged});

  String _label(MapLayer l) {
    switch (l) {
      case MapLayer.satellite:
        return 'Спутник';
      case MapLayer.scheme:
        return 'Схема';
      case MapLayer.hybrid:
        return 'Гибрид';
    }
  }

  IconData _icon(MapLayer l) {
    switch (l) {
      case MapLayer.satellite:
        return Icons.satellite_alt_outlined;
      case MapLayer.scheme:
        return Icons.map_outlined;
      case MapLayer.hybrid:
        return Icons.layers_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Слой карты',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  ...MapLayer.values.map((l) => ListTile(
                        leading: Icon(_icon(l),
                            color: const Color(0xFF0284C7)),
                        title: Text(_label(l)),
                        trailing: current == l
                            ? const Icon(Icons.check,
                                color: Color(0xFF0284C7))
                            : null,
                        onTap: () {
                          onChanged(l);
                          Navigator.pop(context);
                        },
                      )),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(current),
                  size: 20, color: const Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Text(_label(current),
                  style: const TextStyle(
                      color: Color(0xFF0284C7),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
