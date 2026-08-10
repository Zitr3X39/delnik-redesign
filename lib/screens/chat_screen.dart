import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import '../utils/format.dart';
import '../widgets/glass.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String jobId;
  final String userId;
  final String? peerName;
  const ChatScreen({
    super.key,
    required this.jobId,
    required this.userId,
    this.peerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _attaching = false;
  int _lastMessageCount = 0;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    JobProvider.activeChatJobId = widget.jobId;
    JobProvider.activeChatThreadId = widget.userId;
    // Когда открывается клавиатура (поле ввода получает фокус) —
    // прокручиваем чат вниз, чтобы последнее сообщение не пряталось.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<JobProvider>();
      await provider.refreshMessages();
      if (!mounted) return;
      await provider.markThreadRead(widget.jobId, widget.userId);
    });
  }

  @override
  void dispose() {
    if (JobProvider.activeChatJobId == widget.jobId &&
        JobProvider.activeChatThreadId == widget.userId) {
      JobProvider.activeChatJobId = null;
      JobProvider.activeChatThreadId = null;
    }
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reportDialog(BuildContext context, JobProvider provider,
      String peerId, String peerName) async {
    const reasons = [
      'Мошенничество / обман с оплатой',
      'Грубость / хамство',
      'Спам / реклама',
      'Другое',
    ];
    String? chosen;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Пожаловаться на $peerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined, size: 20),
                    title: Text(r),
                    onTap: () {
                      chosen = r;
                      Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
        ],
      ),
    );
    if (chosen != null) {
      await provider.reportUser(peerId, chosen!);
      JobProvider.messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена. Спасибо!')),
      );
    }
  }

  Widget _buildPeerMenu(BuildContext context, JobProvider provider,
      String peerId, String peerName) {
    final blocked = provider.isBlocked(peerId);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value == 'report') {
          await _reportDialog(context, provider, peerId, peerName);
        } else if (value == 'block') {
          provider.blockUser(peerId);
          JobProvider.messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('$peerName заблокирован')),
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
        } else if (value == 'unblock') {
          provider.unblockUser(peerId);
          JobProvider.messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('$peerName разблокирован')),
          );
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'report',
          child: Row(children: [
            Icon(Icons.flag_outlined, size: 18, color: Colors.black54),
            SizedBox(width: 10),
            Text('Пожаловаться'),
          ]),
        ),
        if (blocked)
          const PopupMenuItem(
            value: 'unblock',
            child: Row(children: [
              Icon(Icons.lock_open, size: 18, color: Colors.black54),
              SizedBox(width: 10),
              Text('Разблокировать'),
            ]),
          )
        else
          const PopupMenuItem(
            value: 'block',
            child: Row(children: [
              Icon(Icons.block, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Заблокировать'),
            ]),
          ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await context
        .read<JobProvider>()
        .sendMessage(widget.jobId, widget.userId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) {
      _messageController.clear();
      _focusNode.requestFocus();
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить сообщение. Проверьте интернет.'),
        ),
      );
    }
  }

  Future<void> _attachPhoto() async {
    if (_attaching || _sending) return;
    String? uploadedPath;
    JobProvider? rollbackProvider;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280);
      if (file == null) return;
      setState(() => _attaching = true);
      final bytes = await file.readAsBytes();
      final validationError = JobProvider.photoValidationError(bytes);
      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
        return;
      }
      if (!mounted) return;
      final provider = context.read<JobProvider>();
      rollbackProvider = provider;
      final result = await provider.uploadChatPhoto(
        bytes,
        jobId: widget.jobId,
        threadId: widget.userId,
      );
      if (!result.isSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Не удалось загрузить фото.')),
        );
        return;
      }
      uploadedPath = result.url!;
      if (!mounted) {
        await provider.deleteUploadedChatPhotos([uploadedPath]);
        return;
      }
      final sent = await provider.sendMessage(
        widget.jobId,
        widget.userId,
        _messageController.text.trim(),
        imageUrl: uploadedPath,
      );
      if (!sent) {
        await provider.deleteUploadedChatPhotos([uploadedPath]);
        uploadedPath = null;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Фото не отправлено. Проверьте интернет.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      _messageController.clear();
      _scrollToBottom();
    } catch (error, stackTrace) {
      debugPrint('Attach photo failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (uploadedPath != null && rollbackProvider != null) {
        await rollbackProvider.deleteUploadedChatPhotos([uploadedPath]);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить фотографию.')),
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  Widget _chatImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _openImage(url),
        child: Image.network(
          url,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            width: 200,
            height: 120,
            child: Icon(Icons.broken_image_outlined),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  width: 200,
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
    );
  }

  Widget _chatPhoto(BuildContext context, String imageRef) {
    // Старые сообщения содержат публичный URL из bucket photos.
    if (!JobProvider.isChatPhotoPath(imageRef)) {
      return _chatImage(imageRef);
    }

    // Синхронный кэш ссылок: без FutureBuilder, чтобы фото не мерцали
    // при перестроениях чата (polling, новые сообщения, клавиатура).
    final url = context.watch<JobProvider>().peekChatPhotoUrl(imageRef);
    if (url == null || url.isEmpty) {
      return const SizedBox(
        width: 200,
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _chatImage(url);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, provider, _) {
        final matches =
            provider.jobs.where((j) => j.id == widget.jobId);
        if (matches.isEmpty) {
          return GlassScaffold(
            title: widget.peerName ?? 'Чат',
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Заявка закрыта или удалена — чат недоступен.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 15),
                ),
              ),
            ),
          );
        }
        final job = matches.first;
        final messages = job.chatWith(widget.userId);
        if (_lastMessageCount != messages.length) {
          _lastMessageCount = messages.length;
          _scrollToBottom();
        }
        final hasUnreadIncoming = messages.any((message) =>
            message.senderId != JobProvider.currentUserId &&
            message.readAt == null);
        if (hasUnreadIncoming) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              provider.markThreadRead(widget.jobId, widget.userId);
            }
          });
        }
        final title = widget.peerName ?? job.employerName;
        final meId = JobProvider.currentUserId;
        final peerId =
            meId == job.employerId ? widget.userId : job.employerId;
        final peerPhone = provider.performerById(peerId)?.phone ?? '';
        return GlassScaffold(
          title: title,
          actions: peerId.isEmpty
              ? null
              : [_buildPeerMenu(context, provider, peerId, title)],
          body: Column(
            children: [
              if (peerId.isNotEmpty)
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: peerId,
                        fallbackName: title,
                        asEmployer: peerId == job.employerId,
                      ),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text('Профиль и отзывы',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black45)),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),
              if (peerPhone.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone,
                          size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Телефон для связи: $peerPhone',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Скопировать',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: peerPhone));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Номер скопирован')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              _ChatJobInfo(
                address: job.address,
                description: job.description,
                expanded: _descExpanded,
                onToggleDesc: () =>
                    setState(() => _descExpanded = !_descExpanded),
                onOpenMap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        JobMapScreen(job: job, jobs: provider.visibleJobs),
                  ),
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text('Нет сообщений',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMine =
              msg.senderId.isNotEmpty && msg.senderId == JobProvider.currentUserId;
                          return Align(
                            key: ValueKey(
                              msg.id.isEmpty
                                  ? '${msg.senderId}_${msg.time.microsecondsSinceEpoch}_$index'
                                  : msg.id,
                            ),
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFF075985)
                                    : Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isMine
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (msg.imageUrl.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: _chatPhoto(context, msg.imageUrl),
                                    ),
                                  if (msg.text.isNotEmpty)
                                    Text(
                                      msg.text,
                                      style: TextStyle(
                                          color: isMine
                                              ? Colors.white
                                              : Colors.black87),
                                    ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        formatTime(msg.time),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMine
                                              ? Colors.white60
                                              : Colors.black45,
                                        ),
                                      ),
                                      if (isMine) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          msg.readAt == null
                                              ? Icons.check_rounded
                                              : Icons.done_all_rounded,
                                          size: 15,
                                          color: msg.readAt == null
                                              ? Colors.white60
                                              : const Color(0xFF7DD3FC),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed:
                            (_attaching || _sending) ? null : _attachPhoto,
                        icon: _attaching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4),
                              )
                            : const Icon(Icons.attach_file_rounded),
                        tooltip: 'Прикрепить фото',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: 'Сообщение...',
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        onPressed: _sending ? null : _sendMessage,
                        elevation: 0,
                        child: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Шапка чата: кликабельный адрес (открывает карту с меткой) и
/// сворачиваемое описание заявки.
class _ChatJobInfo extends StatelessWidget {
  final String address;
  final String description;
  final bool expanded;
  final VoidCallback onToggleDesc;
  final VoidCallback onOpenMap;
  const _ChatJobInfo({
    required this.address,
    required this.description,
    required this.expanded,
    required this.onToggleDesc,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty;
    final hasDescription = description.trim().isNotEmpty;
    if (!hasAddress && !hasDescription) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAddress)
            InkWell(
              onTap: onOpenMap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.map_outlined,
                        size: 18, color: Color(0xFF0284C7)),
                  ],
                ),
              ),
            ),
          if (hasAddress && hasDescription)
            const Divider(height: 1),
          if (hasDescription) ...[
            InkWell(
              onTap: onToggleDesc,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.notes_rounded,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Описание заявки',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 26),
                child: Text(
                  description,
                  style: const TextStyle(color: Colors.black87, height: 1.35),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
