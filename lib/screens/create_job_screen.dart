import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/geo.dart';
import '../utils/cities.dart';
import '../widgets/glass.dart';
import '../utils/censor.dart';
import '../utils/categories.dart';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseController = TextEditingController();
  final _workersController = TextEditingController();
  final _payController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final bool _isUrgent = false;
  bool _isFixedPay = false;
  String _category = '';
  bool _showCategories = false;
  bool _submitting = false;
  static const int _maxPhotos = 4;
  final List<Uint8List> _photos = [];

  Future<void> _pickPhotos() async {
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Можно добавить не больше 4 фото.')),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(
          imageQuality: 60, maxWidth: 1280, maxHeight: 1280);
      if (files.isEmpty) return;
      String? rejectedReason;
      for (final file in files) {
        if (_photos.length >= _maxPhotos) {
          rejectedReason = 'Можно добавить не больше 4 фото.';
          break;
        }
        final bytes = await file.readAsBytes();
        final validationError = JobProvider.photoValidationError(bytes);
        if (validationError != null) {
          rejectedReason = validationError;
          continue;
        }
        _photos.add(bytes);
      }
      if (!mounted) return;
      setState(() {});
      if (rejectedReason != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rejectedReason)),
        );
      }
    } catch (error) {
      debugPrint('Photo picker failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выбрать фотографию.')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _streetController.dispose();
    _houseController.dispose();
    _workersController.dispose();
    _payController.dispose();
    super.dispose();
  }

  /// Российский формат времени (24 часа): 6:00 → 06:00, 18:00.
  String _fmtTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<JobProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final jobDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (!jobDate.isAfter(DateTime.now())) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Дата и время должны быть в будущем')),
      );
      return;
    }
    if (provider.jobsLeftToday <= 0) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                'Лимит ${JobProvider.maxJobsPerDay} заявок в день исчерпан. Попробуйте завтра.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final street = _streetController.text.trim();
    final house = _houseController.text.trim();
    // Город заявки — город из профиля автора.
    final city = provider.me.city.trim().isEmpty
        ? myCity
        : provider.me.city.trim();
    // Примерная точка по адресу (может быть неточной).
    final guess = await geocodeAddress(street, house, city: city);
    if (!mounted) return;
    // Без геокодинга ставим камеру в центр своего города, а не в Уфу.
    final cityCenter = RuCities.coordsOf(city);
    final initial = guess != null
        ? LatLng(guess.lat, guess.lng)
        : cityCenter != null
            ? LatLng(cityCenter.lat, cityCenter.lng)
            : LatLng(myLat, myLng);
    // Пользователь ставит точную метку на карте.
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initial: initial,
          address: '$street, д. $house',
        ),
      ),
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _submitting = false);
      return;
    }
    final lat = picked.latitude;
    final lng = picked.longitude;

    // Загрузка фото в облако. При частичном сбое удаляем уже загруженные
    // файлы и не публикуем заявку с неполным набором фотографий.
    final List<String> photoUrls = [];
    for (final bytes in _photos) {
      final result = await provider.uploadPhoto(bytes);
      if (!result.isSuccess) {
        await provider.deleteUploadedPhotos(photoUrls);
        if (!mounted) return;
        setState(() => _submitting = false);
        messenger.showSnackBar(
          SnackBar(content: Text(result.error ?? 'Не удалось загрузить фото.')),
        );
        return;
      }
      photoUrls.add(result.url!);
    }
    if (!mounted) {
      await provider.deleteUploadedPhotos(photoUrls);
      return;
    }

    final job = Job(
      id: '${JobProvider.currentUserId}_${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      address: '$street, д. $house',
      city: city,
      lat: lat,
      lng: lng,
      workersNeeded: int.tryParse(_workersController.text.trim()) ?? 1,
      payPerHour: double.tryParse(_payController.text.trim().replaceAll(',', '.')) ?? 0,
      isFixedPay: _isFixedPay,
      date: jobDate,
      employerName: provider.me.name.isEmpty ? 'Вы' : provider.me.name,
      employerId: JobProvider.currentUserId,
      category: _category,
      isUrgent: _isUrgent,
      photos: photoUrls,
    );
    final ok = provider.addJob(job);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      await provider.deleteUploadedPhotos(photoUrls);
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                'Лимит ${JobProvider.maxJobsPerDay} заявок в день исчерпан. Попробуйте завтра.')),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
          content: Text('Заявка опубликована! Метка добавлена на карту.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsLeft = context.watch<JobProvider>().jobsLeftToday;
    return GlassScaffold(
      title: 'Создать заявку',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel(
                  icon: Icons.work_outline_rounded,
                  title: 'О работе',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (jobsLeft > 0
                            ? AppTheme.primaryColor
                            : AppTheme.dangerColor)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18,
                          color: jobsLeft > 0
                              ? AppTheme.primaryColor
                              : AppTheme.dangerColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Осталось заявок сегодня: $jobsLeft из ${JobProvider.maxJobsPerDay}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название работы',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: requiredCleanValidator,
                  maxLength: 60,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                    hintText:
                        'Чем предстоит заниматься\nЧто взять с собой\nВо сколько начало',
                    hintMaxLines: 3,
                    helperText: 'Чем подробнее — тем быстрее откликнутся',
                  ),
                  maxLines: 4,
                  maxLength: 600,
                  validator: requiredCleanValidator,
                ),
                const SizedBox(height: 16),
                _PhotoPicker(
                  photos: _photos,
                  onAdd: _pickPhotos,
                  onRemove: (i) => setState(() => _photos.removeAt(i)),
                ),
                const SizedBox(height: 20),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () =>
                      setState(() => _showCategories = !_showCategories),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.category_outlined,
                            size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        const Text('Категория',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _category.isEmpty ? 'не выбрана' : _category,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _category.isEmpty
                                    ? Colors.black38
                                    : const Color(0xFF0284C7)),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _showCategories ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _showCategories
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kJobCategories.map((c) {
                    final sel = _category == c;
                    return GestureDetector(
                      onTap: () => setState(() => _category = sel ? '' : c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFFE0F2FE)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF0284C7)
                                    .withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(categoryIcon(c),
                                size: 16,
                                color: sel
                                    ? const Color(0xFF0284C7)
                                    : Colors.black54),
                            const SizedBox(width: 6),
                            Text(c,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? const Color(0xFF0284C7)
                                        : Colors.black54)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionLabel(
                  icon: Icons.location_on_outlined,
                  title: 'Место работы',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(
                    labelText: 'Улица',
                    hintText: 'например: Ленина или 8 Марта',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9A-Za-zА-Яа-яЁё \-.]')),
                  ],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Укажите улицу' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _houseController,
                  decoration: const InputDecoration(
                    labelText: 'Дом',
                    hintText: 'например: 45 / 12к2 / 3а',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9A-Za-zА-Яа-яЁё /.\-]')),
                  ],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Укажите дом' : null,
                ),
                const SizedBox(height: 6),
                const Text(
                  'После заполнения адреса вы поставите точную метку на карте.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                const _SectionLabel(
                  icon: Icons.payments_outlined,
                  title: 'Условия и оплата',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _PayTypeTab(
                        icon: Icons.schedule,
                        label: 'За час',
                        selected: !_isFixedPay,
                        onTap: () => setState(() => _isFixedPay = false),
                      ),
                      _PayTypeTab(
                        icon: Icons.payments_outlined,
                        label: 'Фикс. сумма',
                        selected: _isFixedPay,
                        onTap: () => setState(() => _isFixedPay = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _workersController,
                        decoration: const InputDecoration(
                            labelText: 'Сколько человек'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите число';
                          final n = int.tryParse(v);
                          if (n == null) return 'Только цифры';
                          if (n <= 0) return 'Больше 0';
                          if (n > 50) return 'Не больше 50';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _payController,
                        decoration: InputDecoration(
                            labelText: _isFixedPay
                                ? 'Сумма ₽ за работу'
                                : 'Оплата ₽/час'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите число';
                          final n = double.tryParse(v.replaceAll(',', '.'));
                          if (n == null) return 'Только число';
                          if (n <= 0) return 'Оплата должна быть больше 0';
                          if (n > 10000000) return 'Слишком большая сумма';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel(
                  icon: Icons.event_outlined,
                  title: 'Дата и время',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (!mounted) return;
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FCFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Дата',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.event_rounded,
                                      size: 18,
                                      color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      formatDate(_selectedDate),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                            // Всегда 24-часовой формат (без AM/PM).
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context)
                                  .copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (!mounted) return;
                          if (picked != null) {
                            setState(() => _selectedTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FCFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Время',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 18,
                                      color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _fmtTime24(_selectedTime),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                BigButton(
                  label: _submitting ? 'ПУБЛИКУЕМ…' : 'ОПУБЛИКОВАТЬ',
                  icon: Icons.send,
                  color: AppTheme.primaryColor,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Сегмент переключателя типа оплаты (за час / фикс.).
class _PayTypeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PayTypeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.black54),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}


class _PhotoPicker extends StatelessWidget {
  final List<Uint8List> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  const _PhotoPicker({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          icon: Icons.photo_camera_outlined,
          title: 'Фото (необязательно)',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < photos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      photos[i],
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (photos.length < _CreateJobScreenState._maxPhotos)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: Color(0xFF6B7280)),
                      SizedBox(height: 4),
                      Text('Добавить',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
