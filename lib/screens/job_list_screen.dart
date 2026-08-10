import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../widgets/glass.dart';
import '../widgets/job_card.dart';
import 'job_detail_screen.dart';

/// Тип списка заявок, открываемого из меню «три полоски» в шапке.
enum JobListType { favorites, applications, history }

/// Отдельный экран со списком заявок (Избранное / Мои отклики / История).
class JobListScreen extends StatelessWidget {
  final JobListType type;
  const JobListScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final String title;
    final List<Job> jobs;
    final String empty;
    switch (type) {
      case JobListType.favorites:
        title = 'Избранное';
        jobs = provider.favoriteJobs;
        empty = 'Нажмите \u2665 на заявке, чтобы сохранить её сюда';
        break;
      case JobListType.applications:
        title = 'Мои отклики';
        jobs = provider.myApplications;
        empty = 'Вы ещё никуда не откликались';
        break;
      case JobListType.history:
        title = 'История';
        jobs = provider.historyJobs;
        empty = 'Завершённые и закрытые заявки появятся здесь';
        break;
    }
    return GlassScaffold(
      title: title,
      body: jobs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  empty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: jobs
                  .map((job) => JobCard(
                        job: job,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(jobId: job.id),
                          ),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
