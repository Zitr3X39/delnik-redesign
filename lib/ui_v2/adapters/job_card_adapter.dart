import 'package:flutter/foundation.dart';

import '../../models/job.dart';
import '../../utils/categories.dart';
import '../../utils/format.dart';
import '../../utils/geo.dart';
import '../widgets/job_card_v2.dart';

/// Адаптер `Job -> JobCardV2`.
///
/// Карточка сама ничего не знает про модель и провайдеры — вся
/// склейка здесь, в одном месте. Когда появится слой данных
/// `data/repositories`, правится только этот файл, а не экраны.
extension JobCardV2Adapter on Job {
  JobCardV2 toCardV2({
    required bool isFavorite,
    required double? employerRating,
    required VoidCallback onTap,
    VoidCallback? onFavoriteTap,
  }) {
    return JobCardV2(
      title: title,
      priceText: payText,
      // Сервер может скрыть точный адрес у чужих заявок — тогда город.
      addressText: locationHidden
          ? (city.isEmpty ? 'Адрес после отклика' : city)
          : (address.isEmpty ? 'Адрес не указан' : address),
      distanceText: formatDistance(distanceFromMe(lat, lng)),
      timeText: formatDateTime(date),
      employerName: employerName,
      employerRating: employerRating,
      slotsLeft: slotsLeft < 0 ? 0 : slotsLeft,
      workersTotal: workersNeeded,
      photoUrl: photos.isEmpty ? null : photos.first,
      categoryIcon: categoryIcon(category),
      status: isClosed
          ? JobCardStatus.closed
          : isFull
              ? JobCardStatus.full
              : JobCardStatus.open,
      isUrgent: isUrgent,
      isFavorite: isFavorite,
      onTap: onTap,
      onFavoriteTap: onFavoriteTap,
    );
  }
}
