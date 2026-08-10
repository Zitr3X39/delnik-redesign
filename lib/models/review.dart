class Review {
  final String id;
  final String jobId;
  final String authorId;
  final String authorName;
  final String targetId;
  final int stars;
  final String text;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.jobId,
    required this.authorId,
    required this.authorName,
    required this.targetId,
    required this.stars,
    required this.text,
    required this.createdAt,
  });

  factory Review.fromRow(Map<String, dynamic> row) => Review(
        id: '${row['id'] ?? ''}',
        jobId: '${row['job_id'] ?? ''}',
        authorId: '${row['author_id'] ?? ''}',
        authorName: '${row['author_name'] ?? 'Пользователь'}',
        targetId: '${row['target_id'] ?? ''}',
        stars: (row['stars'] as num?)?.toInt() ?? 0,
        text: '${row['text'] ?? ''}',
        createdAt: DateTime.tryParse('${row['created_at']}')?.toLocal() ??
            DateTime.now(),
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'job_id': jobId,
        'author_id': authorId,
        'author_name': authorName,
        'target_id': targetId,
        'stars': stars,
        'text': text,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
