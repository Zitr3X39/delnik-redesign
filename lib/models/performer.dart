class Performer {
  final String id;
  String name;
  String phone;
  String city;
  int age;
  double rating; // репутация как ИСПОЛНИТЕЛЯ (оценивают работодатели)
  int ratingCount;
  int completedJobs;
  double employerRating; // репутация как ЗАКАЗЧИКА (оценивают рабочие)
  int employerRatingCount;
  DateTime? loggedOutAt; // момент выхода из аккаунта (3ч отсрочка удаления заявок)
  List<String> blocked; // id заблокированных пользователей
  List<String> favorites; // id избранных заявок

  /// Анкета заполнена. Раньше факт регистрации определялся по полю phone,
  /// но в общую базу phone не попадает (toSharedJson его вырезает) —
  /// из-за этого при каждом входе пользователя снова вело на анкету. Теперь флаг явный.
  bool registered;

  /// До какого момента аккаунт заблокирован администратором.
  /// null — блокировки нет. Далёкая дата (год 9999) — бан навсегда.
  DateTime? bannedUntil;

  /// Причина блокировки (показывается пользователю).
  String banReason;

  /// Когда аккаунт был создан — нужно для статистики в панели разработчика.
  DateTime? createdAt;

  Performer({
    required this.id,
    this.name = '',
    this.phone = '',
    this.city = '',
    this.age = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.completedJobs = 0,
    this.employerRating = 0.0,
    this.employerRatingCount = 0,
    this.loggedOutAt,
    List<String>? blocked,
    List<String>? favorites,
    this.registered = false,
    this.bannedUntil,
    this.banReason = '',
    this.createdAt,
  })  : blocked = blocked ?? [],
        favorites = favorites ?? [];

  /// Действует ли блокировка прямо сейчас.
  bool get isBanned {
    final until = bannedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  /// Бан без срока (навсегда).
  bool get isPermanentlyBanned {
    final until = bannedUntil;
    return until != null && until.year >= 9000;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'city': city,
        'age': age,
        'rating': rating,
        'ratingCount': ratingCount,
        'completedJobs': completedJobs,
        'employerRating': employerRating,
        'employerRatingCount': employerRatingCount,
        'loggedOutAt': loggedOutAt?.toUtc().toIso8601String(),
        'blocked': blocked,
        'favorites': favorites,
        'registered': registered,
        'bannedUntil': bannedUntil?.toUtc().toIso8601String(),
        'banReason': banReason,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  // Версия профиля для ОБЩЕЙ базы (shared_profiles): без телефона и
  // приватных настроек. blocked/favorites хранятся в private_user_state,
  // доступной только владельцу строки.
  Map<String, dynamic> toSharedJson() {
    final map = toJson();
    map.remove('phone');
    map.remove('blocked');
    map.remove('favorites');
    return map;
  }

  factory Performer.fromJson(Map<String, dynamic> json) => Performer(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        city: (json['city'] ?? '') as String,
        age: (json['age'] ?? 0) as int,
        rating: (json['rating'] ?? 0).toDouble(),
        ratingCount: (json['ratingCount'] ?? 0) as int,
        completedJobs: (json['completedJobs'] ?? 0) as int,
        employerRating: (json['employerRating'] ?? 0).toDouble(),
        employerRatingCount: (json['employerRatingCount'] ?? 0) as int,
        loggedOutAt: json['loggedOutAt'] != null
            ? DateTime.tryParse('${json['loggedOutAt']}')?.toLocal()
            : null,
        blocked: ((json['blocked'] ?? []) as List)
            .map((e) => e as String)
            .toList(),
        favorites: ((json['favorites'] ?? []) as List)
            .map((e) => e as String)
            .toList(),
        // Старые профили без флага: считаем зарегистрированными, если есть имя.
        registered: (json['registered'] as bool?) ??
            ((json['name'] ?? '') as String).trim().isNotEmpty,
        bannedUntil: json['bannedUntil'] != null
            ? DateTime.tryParse('${json['bannedUntil']}')?.toLocal()
            : null,
        banReason: (json['banReason'] ?? '') as String,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse('${json['createdAt']}')?.toLocal()
            : null,
      );
}
