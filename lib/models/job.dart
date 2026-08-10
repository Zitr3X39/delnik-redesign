class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String imageUrl;
  final DateTime time;
  final DateTime? readAt;

  ChatMessage({
    this.id = '',
    this.senderId = '',
    required this.senderName,
    required this.text,
    this.imageUrl = '',
    required this.time,
    this.readAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'imageUrl': imageUrl,
        'time': time.toIso8601String(),
        'readAt': readAt?.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] ?? '') as String,
        senderId: (json['senderId'] ?? '') as String,
        senderName: json['senderName'] as String,
        text: json['text'] as String,
        imageUrl: (json['imageUrl'] ?? '') as String,
        time: DateTime.parse(json['time'] as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.tryParse('${json['readAt']}'),
      );
}

// Статусы шагов работы (на каждого исполнителя отдельно).
class JobStage {
  static const int applied = 0; // Откликнулся
  static const int accepted = 1; // Работодатель принял
  static const int inProgress = 2; // В работе
  static const int completed = 3; // Завершено (обе стороны подтвердили)

  static const List<String> labels = [
    'Откликнулся',
    'Работодатель принял',
    'В работе',
    'Завершено',
  ];

  static String label(int s) =>
      (s >= 0 && s < labels.length) ? labels[s] : labels[0];
}

class Job {
  final String id;
  final String title;
  final String description;
  String address;

  /// true — сервер скрыл точный адрес (заявка укомплектована чужими
  /// откликами). Показываем город/«адрес после отклика», не метку на карте.
  /// Не сериализуется: при каждой синхронизации выставляется заново.
  bool locationHidden;

  /// Город заявки. Заполняется из города автора при создании.
  /// У старых заявок пустой — тогда город определяется по координатам.
  final String city;
  double lat;
  double lng;
  final int workersNeeded;
  final double payPerHour; // если isFixedPay=true — это фиксированная сумма за работу
  final bool isFixedPay;
  final DateTime date;
  final DateTime createdAt;
  final String employerName;
  final String employerId;
  final String category;
  final List<String> photos;
  final bool isUrgent;
  final List<String> applicants;
  double rating;
  int ratingCount;
  bool isClosed;
  DateTime? closedAt;

  /// Момент, когда заявка заполнилась (набраны все места). Нужен, чтобы
  /// у посторонних она пропадала через 15 секунд после набора откликов.
  DateTime? fullAt;

  /// Уникальные зрители заявки (id пользователей, открывавших детали).
  final List<String> viewedBy;

  /// Кого работодатель отклонил от заявки — повторно откликнуться нельзя.
  final List<String> rejectedApplicants;

  /// Отдельная переписка с каждым пользователем: userId -> список сообщений.
  final Map<String, List<ChatMessage>> chats;

  /// Исполнители, которых работодатель уже оценил.
  final List<String> ratedApplicants;

  /// Поставленные оценки исполнителям: performerId -> звёзды.
  final Map<String, double> ratings;

  /// Шаг работы по каждому исполнителю: workerId -> JobStage.
  final Map<String, int> stages;

  /// Кого работодатель отметил как выполнившего.
  final List<String> employerDone;

  /// Какие исполнители сами подтвердили завершение.
  final List<String> workerDone;

  /// Оценки работодателя от рабочих: workerId -> звёзды.
  final Map<String, double> employerRatings;

  /// Исполнители, которым уже засчитана завершённая работа.
  final List<String> completedCreditedApplicants;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.address,
    this.locationHidden = false,
    this.city = '',
    required this.lat,
    required this.lng,
    required this.workersNeeded,
    required this.payPerHour,
    this.isFixedPay = false,
    required this.date,
    DateTime? createdAt,
    required this.employerName,
    this.employerId = '',
    this.category = '',
    List<String>? photos,
    this.isUrgent = false,
    List<String>? applicants,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.isClosed = false,
    this.closedAt,
    this.fullAt,
    List<String>? rejectedApplicants,
    List<String>? viewedBy,
    Map<String, List<ChatMessage>>? chats,
    List<String>? ratedApplicants,
    Map<String, double>? ratings,
    Map<String, int>? stages,
    List<String>? employerDone,
    List<String>? workerDone,
    Map<String, double>? employerRatings,
    List<String>? completedCreditedApplicants,
  })  : applicants = applicants ?? [],
        photos = photos ?? [],
        createdAt = createdAt ?? DateTime.now(),
        chats = chats ?? {},
        rejectedApplicants = rejectedApplicants ?? [],
        viewedBy = viewedBy ?? [],
        ratedApplicants = ratedApplicants ?? [],
        ratings = ratings ?? {},
        stages = stages ?? {},
        employerDone = employerDone ?? [],
        workerDone = workerDone ?? [],
        employerRatings = employerRatings ?? {},
        completedCreditedApplicants = completedCreditedApplicants ?? [];

  int get slotsLeft => workersNeeded - applicants.length;
  int get viewsCount => viewedBy.length;
  bool get isFull => slotsLeft <= 0;

  /// После закрытия карточка ещё 15 секунд видна участникам,
  /// затем исчезает из ленты и карты, но остаётся в истории с чатом.
  bool get isInCloseGracePeriod {
    if (!isClosed || closedAt == null) return false;
    return DateTime.now().isBefore(
      closedAt!.add(const Duration(seconds: 15)),
    );
  }

  // Заполненная заявка скрыта от посторонних: её видят только
  // работодатель и те, кто уже откликнулся.
  bool isVisibleTo(String userId) {
    if (employerId == userId || applicants.contains(userId)) return true;
    if (!isFull) return true;
    // Заявка заполнена: посторонние видят её ещё 15 секунд после набора,
    // затем она исчезает у всех, кроме участников.
    if (fullAt == null) return false;
    return DateTime.now().isBefore(fullAt!.add(const Duration(seconds: 15)));
  }

  // Заявка исчезает через 12 часов после окончания выбранного дня.
  bool get isExpired {
    final endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59);
    return DateTime.now().isAfter(endOfDay.add(const Duration(hours: 12)));
  }

  /// Переписка с конкретным пользователем.
  List<ChatMessage> chatWith(String userId) =>
      chats.putIfAbsent(userId, () => []);

  /// Оценивал ли работодатель этого исполнителя.
  bool ratedBy(String userId) => ratedApplicants.contains(userId);

  /// Текущий шаг исполнителя.
  int stageOf(String workerId) {
    if (employerDone.contains(workerId) && workerDone.contains(workerId)) {
      return JobStage.completed;
    }
    return stages[workerId] ?? JobStage.applied;
  }

  bool employerConfirmed(String workerId) => employerDone.contains(workerId);
  bool workerConfirmed(String workerId) => workerDone.contains(workerId);
  bool isCompletedFor(String workerId) =>
      employerDone.contains(workerId) && workerDone.contains(workerId);

  /// Текст оплаты с учётом типа (за час или фиксированно).
  String get payText => isFixedPay
      ? '${payPerHour.toInt()} ₽ за работу'
      : '${payPerHour.toInt()} ₽/час';

  /// Копия заявки с изменёнными полями формы. Всё остальное состояние
  /// (отклики, чаты, оценки, этапы) переносится как есть.
  Job copyWithEdits({
    String? title,
    String? description,
    String? address,
    String? city,
    double? lat,
    double? lng,
    int? workersNeeded,
    double? payPerHour,
    bool? isFixedPay,
    DateTime? date,
    String? category,
    List<String>? photos,
  }) {
    return Job(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      workersNeeded: workersNeeded ?? this.workersNeeded,
      payPerHour: payPerHour ?? this.payPerHour,
      isFixedPay: isFixedPay ?? this.isFixedPay,
      date: date ?? this.date,
      createdAt: createdAt,
      employerName: employerName,
      employerId: employerId,
      category: category ?? this.category,
      photos: photos ?? this.photos,
      isUrgent: isUrgent,
      applicants: applicants,
      rating: rating,
      ratingCount: ratingCount,
      isClosed: isClosed,
      closedAt: closedAt,
      fullAt: fullAt,
      rejectedApplicants: rejectedApplicants,
      viewedBy: viewedBy,
      chats: chats,
      ratedApplicants: ratedApplicants,
      ratings: ratings,
      stages: stages,
      employerDone: employerDone,
      workerDone: workerDone,
      employerRatings: employerRatings,
      completedCreditedApplicants: completedCreditedApplicants,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'address': address,
        'city': city,
        'lat': lat,
        'lng': lng,
        'workersNeeded': workersNeeded,
        'payPerHour': payPerHour,
        'isFixedPay': isFixedPay,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'employerName': employerName,
        'employerId': employerId,
        'category': category,
        'photos': photos,
        'isUrgent': isUrgent,
        'applicants': applicants,
        'rating': rating,
        'ratingCount': ratingCount,
        'isClosed': isClosed,
        'closedAt': closedAt?.toIso8601String(),
        'fullAt': fullAt?.toIso8601String(),
        'rejectedApplicants': rejectedApplicants,
        'viewedBy': viewedBy,
        'chats': chats.map((k, v) =>
            MapEntry(k, v.map((m) => m.toJson()).toList())),
        'ratedApplicants': ratedApplicants,
        'ratings': ratings,
        'stages': stages,
        'employerDone': employerDone,
        'workerDone': workerDone,
        'employerRatings': employerRatings,
        'completedCreditedApplicants': completedCreditedApplicants,
      };

  /// Версия для облака без переписки (чат в отдельной таблице messages).
  Map<String, dynamic> toRemoteJson() {
    final m = toJson();
    m.remove('chats');
    return m;
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    final Map<String, List<ChatMessage>> parsedChats = {};
    final rawChats = json['chats'];
    if (rawChats is Map) {
      rawChats.forEach((key, value) {
        parsedChats[key as String] = ((value ?? []) as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } else if (json['messages'] is List) {
      parsedChats['currentUser'] = (json['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Job(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      address: (json['address'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      workersNeeded: (json['workersNeeded'] ?? 0) as int,
      payPerHour: (json['payPerHour'] ?? 0).toDouble(),
      isFixedPay: (json['isFixedPay'] ?? false) as bool,
      date: DateTime.parse(json['date'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.parse(json['date'] as String),
      employerName: json['employerName'] as String,
      employerId: (json['employerId'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      photos: ((json['photos'] ?? const []) as List)
          .map((e) => e as String)
          .toList(),
      isUrgent: (json['isUrgent'] ?? false) as bool,
      applicants: ((json['applicants'] ?? []) as List)
          .map((e) => e as String)
          .toList(),
      rating: (json['rating'] ?? 0).toDouble(),
      ratingCount: (json['ratingCount'] ?? 0) as int,
      isClosed: (json['isClosed'] ?? false) as bool,
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.tryParse('${json['closedAt']}'),
      fullAt: json['fullAt'] == null
          ? null
          : DateTime.tryParse('${json['fullAt']}'),
      rejectedApplicants: ((json['rejectedApplicants'] ?? []) as List)
          .map((e) => e as String)
          .toList(),
      viewedBy: ((json['viewedBy'] ?? []) as List)
          .map((e) => e as String)
          .toList(),
      chats: parsedChats,
      ratedApplicants: ((json['ratedApplicants'] ?? []) as List)
          .map((e) => e as String)
          .toList(),
      ratings: ((json['ratings'] ?? {}) as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble())),
      stages: ((json['stages'] ?? {}) as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt())),
      employerDone: ((json['employerDone'] ?? []) as List)
          .map((e) => e as String)
          .toList(),
      workerDone: ((json['workerDone'] ?? []) as List)
          .map((e) => e as String)
          .toList(),
      employerRatings: ((json['employerRatings'] ?? {}) as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble())),
      completedCreditedApplicants:
          ((json['completedCreditedApplicants'] ?? []) as List)
              .map((e) => e as String)
              .toList(),
    );
  }
}
