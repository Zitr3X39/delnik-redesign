import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/glass.dart';
import 'job_detail_screen.dart';

/// Спутниковая карта с пинами заявок (как в Яндекс.Сменах).
class MapView extends StatefulWidget {
  final List<Job> jobs;
  final Job? focusJob;
  const MapView({super.key, required this.jobs, this.focusJob});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with TickerProviderStateMixin {
  final MapController _controller = MapController();

  /// Центр карты — город из профиля, а не жёстко Уфа.
  LatLng get _cityCenter => LatLng(myCityLat, myCityLng);

  /// Город, под который уже настроена камера — чтобы при смене
  /// города в профиле карта сама переехала куда надо.
  String _shownCity = myCity;
  static const double _defaultZoom = 13;
  AnimationController? _anim;
  LatLng? _currentLocation;
  bool _locating = false;
  // По умолчанию «Схема» (OSM): русские подписи улиц и быстрая загрузка —
  // как в Яндекс.Картах. Спутник/гибрид — по выбору пользователя.
  MapLayer _layer = MapLayer.scheme;

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пользователь сменил город — плавно переносим карту в новый город.
    if (_shownCity != myCity) {
      _shownCity = myCity;
      if (widget.focusJob == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _flyTo(_cityCenter, _defaultZoom);
        });
      }
    }
  }

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  /// Плавное перемещение камеры к точке.
  void _animateTo(LatLng dest, double destZoom,
      {Duration duration = const Duration(milliseconds: 650)}) {
    final camera = _controller.camera;
    final latTween =
        Tween<double>(begin: camera.center.latitude, end: dest.latitude);
    final lngTween = Tween<double>(
        begin: camera.center.longitude, end: dest.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);
    _anim?.dispose();
    final controller = AnimationController(vsync: this, duration: duration);
    _anim = controller;
    final curved =
        CurvedAnimation(parent: controller, curve: Curves.easeInOut);
    controller.addListener(() {
      _controller.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    });
    controller.forward();
  }

  /// Перелёт к точке. На большом расстоянии (метка в другом городе) сначала
  /// отдаляемся на низкий зум, чтобы тайлы региона успели подгрузиться,
  /// и только потом плавно наезжаем на метку — иначе карта «летит через
  /// пустоту» и белые квадраты портят вид.
  void _flyTo(LatLng dest, double destZoom) {
    final cam = _controller.camera;
    final distKm = distanceKm(cam.center.latitude, cam.center.longitude,
        dest.latitude, dest.longitude);
    if (distKm < 25) {
      // В пределах города — обычный плавный переезд.
      _animateTo(dest, destZoom, duration: const Duration(milliseconds: 450));
      return;
    }
    // Другой город: фаза 1 — быстрый переезд на низкий зум, фаза 2 — наезд.
    final travelZoom = (destZoom - 5).clamp(4.0, 8.0);
    _animateTo(dest, travelZoom, duration: const Duration(milliseconds: 550));
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _animateTo(dest, destZoom, duration: const Duration(milliseconds: 600));
    });
  }

  /// Плавно меняет зум на [delta], оставаясь в той же точке.
  void _zoomBy(double delta) {
    final camera = _controller.camera;
    final newZoom = (camera.zoom + delta).clamp(3.0, 18.0);
    _animateTo(camera.center, newZoom);
  }

  Future<void> _goToMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      // Служба геолокации выключена в системе — предлагаем открыть настройки.
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
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 12));
      setGpsPosition(pos.latitude, pos.longitude);
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = point);
      _animateTo(point, 15);
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

  /// Диалог с предложением открыть системные настройки: включить геолокацию
  /// (serviceDisabled=true) либо разрешить доступ приложению (false).
  Future<void> _promptOpenSettings({required bool serviceDisabled}) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(serviceDisabled
            ? 'Геолокация выключена'
            : 'Нет доступа к геолокации'),
        content: Text(serviceDisabled
            ? 'Чтобы найти заявки рядом, включите геолокацию (GPS) в настройках телефона.'
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

  void _onJobTap(Job job) {
    // Метка в другом городе — летим через низкий зум, чтобы карта успела
    // подгрузиться, а не «падала» на пустоту.
    _flyTo(LatLng(job.lat, job.lng), 15);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _openJob(context, job);
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.jobs;
    // Адрес больше не скрываем. На карту ставим заявки с координатами —
    // без координат метку некуда повесить.
    final mappable = active
        .where((job) => (job.lat != 0 || job.lng != 0))
        .toList();
    // Заявка, по которой открыта карта, показывается всегда — даже если
    // она закрыта и не входит в активный список (карта открыта по её адресу).
    final focus = widget.focusJob;
    if (focus != null &&
        (focus.lat != 0 || focus.lng != 0) &&
        !mappable.any((j) => j.id == focus.id)) {
      mappable.add(focus);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _cityCenter,
            initialZoom: _defaultZoom,
            minZoom: 3,
            maxZoom: 18,
            // Жесты: щипок пальцами, перетаскивание, двойной тап и колесо —
            // всё включено, кроме поворота карты.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              final f = widget.focusJob;
              if (f != null) {
                _flyTo(LatLng(f.lat, f.lng), 16);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _layer == MapLayer.scheme
                  ? osmSchemeTileUrl
                  : esriSatelliteTileUrl,
              userAgentPackageName: 'com.shabashka.shabashka_app',
              maxZoom: 18,
              // Держим запас тайлов вокруг экрана и не копим битые — при
              // перелёте в другой город карта сразу показывает улицы,
              // а не белые квадраты.
              keepBuffer: 3,
              evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
            ),
            // Гибрид: спутник + русская схема OSM полупрозрачно (подписи
            // улиц по-русски, как в Яндекс.Картах). Английские подписи
            // Esri больше не используем — они давали «Moscow» вместо «Москва».
            if (_layer == MapLayer.hybrid)
              Opacity(
                opacity: 0.55,
                child: TileLayer(
                  urlTemplate: osmSchemeTileUrl,
                  userAgentPackageName: 'com.shabashka.shabashka_app',
                  maxZoom: 18,
                  keepBuffer: 3,
                  evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                ),
              ),
            // Моя точка («Вы здесь»).
            MarkerLayer(
              markers: _currentLocation == null
                  ? const []
                  : [
                      Marker(
                        point: _currentLocation!,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ],
            ),
            // Пины заявок.
            MarkerLayer(
              markers: mappable.map((job) {
                return Marker(
                  point: LatLng(job.lat, job.lng),
                  width: 150,
                  height: 64,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _onJobTap(job),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black38, blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            job.payText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on,
                          size: 34,
                          color: job.isUrgent
                              ? Colors.redAccent
                              : job.isClosed
                                  ? Colors.blueGrey
                                  : const Color(0xFF0284C7),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Кнопки зума + / −.
        Positioned(
          right: 16,
          bottom: 188,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'zoomIn',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0284C7),
                onPressed: () => _zoomBy(1),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoomOut',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0284C7),
                onPressed: () => _zoomBy(-1),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
        // Кнопка «На моё место».
        Positioned(
          right: 16,
          bottom: 118,
          child: FloatingActionButton(
            heroTag: 'toMe',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0284C7),
            onPressed: _locating ? null : _goToMe,
            child: _locating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
        // Переключатель слоёв карты (как в Яндекс.Картах).
        Positioned(
          left: 16,
          top: 16,
          child: _LayerSwitcher(
            current: _layer,
            onChanged: (l) => setState(() => _layer = l),
          ),
        ),
      ],
    );
  }

  void _openJob(BuildContext context, Job job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(job.address,
                        style: const TextStyle(color: Colors.black54))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    size: 16, color: AppTheme.successColor),
                const SizedBox(width: 4),
                Text(job.payText,
                    style: const TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                const Icon(Icons.near_me,
                    size: 15, color: Colors.black45),
                const SizedBox(width: 4),
                Text(formatDistance(
                    distanceFromMe(job.lat, job.lng))),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          JobDetailScreen(jobId: job.id),
                    ),
                  );
                },
                child: const Text('Открыть заявку'),
              ),
            ),
          ],
        ),
        ),
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

/// Полноэкранная карта с фокусом на одной заявке (открывается из деталей заявки).
class JobMapScreen extends StatelessWidget {
  final Job job;
  final List<Job> jobs;
  const JobMapScreen({super.key, required this.job, required this.jobs});

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(job.address.isEmpty ? 'На карте' : job.address),
        ),
        body: MapView(jobs: jobs, focusJob: job),
      ),
    );
  }
}
