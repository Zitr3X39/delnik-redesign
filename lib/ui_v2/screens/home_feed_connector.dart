import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/job_provider.dart';
import '../../screens/create_job_screen.dart';
import '../../screens/job_detail_screen.dart';
import '../../widgets/city_picker.dart';
import '../adapters/job_card_adapter.dart';
import '../theme/tokens.dart';
import '../ui_v2_flag.dart';
import 'home_feed_screen_v2.dart';

/// Мост между новым UI (ui_v2) и существующим JobProvider.
///
/// Вся логика данных остаётся в провайдере — здесь только подписка,
/// фильтр категории и навигация на пока ещё legacy-экраны (детали,
/// создание заявки). Когда появятся `data/repositories` и go_router,
/// правится этот файл, а не экраны и не карточка.
class HomeFeedConnectorV2 extends StatefulWidget {
  const HomeFeedConnectorV2({super.key});

  @override
  State<HomeFeedConnectorV2> createState() => _HomeFeedConnectorV2State();
}

class _HomeFeedConnectorV2State extends State<HomeFeedConnectorV2> {
  String? _category;

  Future<void> _changeCity(JobProvider provider) async {
    final picked = await showCityPicker(context);
    if (picked == null || !mounted) return;
    provider.updateProfile(city: picked.name);
  }

  void _confirmSwitchToLegacy() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Дизайн'),
        content: const Text(
          'Сейчас включён новый дизайн (v2, в разработке).\n\n'
          'Обратный путь есть всегда: в старой ленте нажмите ✨ '
          'в правом верхнем углу.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Остаться'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              UiV2Flag.setEnabled(false);
            },
            child: const Text('Вернуть старый'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, provider, _) {
        final c = context.appColors;
        final all = provider.visibleJobs;
        final jobs = _category == null
            ? all
            : all.where((j) => j.category == _category).toList();

        return HomeFeedScreenV2(
          cityName: provider.me.city,
          selectedCategory: _category,
          onCategorySelected: (value) => setState(() => _category = value),
          onCityTap: () => _changeCity(provider),
          onLogoLongPress: _confirmSwitchToLegacy,
          isLoading: !provider.loaded,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateJobScreen()),
            ),
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Заявка'),
          ),
          cards: [
            for (final job in jobs)
              job.toCardV2(
                isFavorite: provider.isFavorite(job.id),
                employerRating:
                    provider.employerRatingCountFor(job.employerId) > 0
                        ? provider.employerRatingFor(job.employerId)
                        : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(jobId: job.id),
                  ),
                ),
                onFavoriteTap: () =>
                    context.read<JobProvider>().toggleFavorite(job.id),
              ),
          ],
        );
      },
    );
  }
}
