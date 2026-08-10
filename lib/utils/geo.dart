import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'cities.dart';

// Опорная точка «моё местоположение». Сначала — центр выбранного города,
// потом — реальная GPS-локация, когда пользователь разрешит геопозицию.
double myLat = 54.7388;
double myLng = 55.9721;

/// Город, выбранный пользователем в профиле. От него зависят центр карты,
/// порядок заявок в ленте и геокодирование адреса при создании заявки.
String myCity = 'Уфа';

/// Центр выбранного города (не путать с myLat/myLng — там может быть GPS).
double myCityLat = 54.7388;
double myCityLng = 55.9721;

/// Была ли уже получена реальная GPS-позиция. Пока нет — считаем расстояния
/// от центра города, чтобы цифры в ленте были осмысленными, а не «от Уфы».
bool hasGpsFix = false;

/// Привязывает географию приложения к городу из профиля.
/// Если GPS ещё не определён, «моё место» тоже становится центром города.
void setMyCity(String city) {
  final trimmed = city.trim();
  if (trimmed.isEmpty) return;
  myCity = trimmed;
  final found = RuCities.byName(trimmed);
  if (found == null) return;
  myCityLat = found.lat;
  myCityLng = found.lng;
  if (!hasGpsFix) {
    myLat = found.lat;
    myLng = found.lng;
  }
}

/// Запоминает реальную GPS-позицию.
void setGpsPosition(double lat, double lng) {
  myLat = lat;
  myLng = lng;
  hasGpsFix = true;
}

double _deg2rad(double d) => d * pi / 180.0;

/// Расстояние между двумя точками в километрах (формула гаверсинуса).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double distanceFromMe(double lat, double lng) =>
    distanceKm(myLat, myLng, lat, lng);

/// Расстояние от центра выбранного города — по нему строится порядок
/// заявок из других городов в ленте (чем дальше — тем ниже).
double distanceFromMyCity(double lat, double lng) =>
    distanceKm(myCityLat, myCityLng, lat, lng);

/// Считается ли точка «своим городом» для старых заявок без поля city.
/// 60 км — запас на пригороды и крупные агломерации.
bool isNearMyCity(double lat, double lng) =>
    distanceFromMyCity(lat, lng) <= 60;

String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} м';
  return '${km.toStringAsFixed(1)} км';
}

/// Результат геокодирования.
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);
}

/// Превращает адрес (улица + дом) в указанном городе в координаты
/// через бесплатный геокодер OpenStreetMap (Nominatim).
/// Возвращает null, если адрес не найден или нет сети.
Future<GeoPoint?> geocodeUfaAddress(String street, String house,
    {String city = ''}) async {
  final cityName = city.trim().isEmpty ? myCity : city.trim();
  final query = Uri.encodeQueryComponent('$cityName, $street $house');
  final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=ru&q=$query');
  try {
    final resp = await http.get(
      url,
      headers: {'User-Agent': 'RabochiyApp/1.0 (gig work app)'},
    ).timeout(const Duration(seconds: 12));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List && data.isNotEmpty) {
        final first = data.first as Map<String, dynamic>;
        final lat = double.tryParse('${first['lat']}');
        final lon = double.tryParse('${first['lon']}');
        if (lat != null && lon != null) return GeoPoint(lat, lon);
      }
    }
  } catch (_) {
    // Нет сети / ошибка — вернём null, вызывающий подставит центр города.
  }
  return null;
}

/// Тайлы карты (OpenStreetMap — доступно в РФ без VPN).
const String satelliteTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Примерная точка по адресу (точную метку ставит пользователь вручную).
class GeoResult {
  final double lat;
  final double lng;
  final String label;
  const GeoResult(this.lat, this.lng, this.label);
}

/// Примерное геокодирование адреса в выбранном городе через Nominatim (OSM).
Future<GeoResult?> geocodeAddress(String street, String house,
    {String city = ''}) async {
  final cityName = city.trim().isEmpty ? myCity : city.trim();
  final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&limit=1&accept-language=ru'
      '&city=${Uri.encodeQueryComponent(cityName)}'
      '&country=${Uri.encodeQueryComponent('Россия')}'
      '&street=${Uri.encodeQueryComponent('$house $street')}');
  try {
    final resp = await http.get(
      url,
      headers: {'User-Agent': 'RabochiyApp/1.0 (gig work app)'},
    ).timeout(const Duration(seconds: 12));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List && data.isNotEmpty) {
        final m = data.first as Map<String, dynamic>;
        final lat = double.tryParse('${m['lat']}');
        final lon = double.tryParse('${m['lon']}');
        if (lat != null && lon != null) {
          return GeoResult(lat, lon, '${m['display_name'] ?? ''}');
        }
      }
    }
  } catch (_) {}
  return null;
}

/// Слои карты (переключаются как в Яндекс.Картах).
enum MapLayer { satellite, scheme, hybrid }

/// Обычная схема OpenStreetMap (оставляем по требованию — работает в РФ).
const String osmSchemeTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Свежие спутниковые снимки Esri World Imagery (без ключа и без VPN).
const String esriSatelliteTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
