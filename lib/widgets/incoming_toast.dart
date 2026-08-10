import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/job_provider.dart';
import '../screens/chat_screen.dart';

/// Компактное уведомление о новом сообщении: появляется сбоку
/// сверху, с кнопкой перехода в чат. Исчезает через 5 секунд.
void showIncomingToast({
  required String jobId,
  required String threadId,
  required String senderName,
  required String text,
}) {
  final navState = JobProvider.navigatorKey.currentState;
  final overlay = navState?.overlay;
  if (overlay == null) return;
  late OverlayEntry entry;
  bool removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => _IncomingToast(
      senderName: senderName,
      text: text,
      onOpen: () {
        remove();
        navState!.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              jobId: jobId,
              userId: threadId,
              peerName: senderName,
            ),
          ),
        );
      },
      onClose: remove,
    ),
  );
  overlay.insert(entry);
}

/// Уведомление о событии (новый отклик, принятие и т.д.).
/// При нажатии открывает чат с собеседником.
void showInfoToast({
  required String title,
  required String text,
  required String jobId,
  required String threadId,
  required String peerName,
}) {
  final navState = JobProvider.navigatorKey.currentState;
  final overlay = navState?.overlay;
  if (overlay == null) return;
  late OverlayEntry entry;
  bool removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => _IncomingToast(
      senderName: title,
      text: text,
      onOpen: () {
        remove();
        navState!.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              jobId: jobId,
              userId: threadId,
              peerName: peerName,
            ),
          ),
        );
      },
      onClose: remove,
    ),
  );
  overlay.insert(entry);
}

class _IncomingToast extends StatefulWidget {
  final String senderName;
  final String text;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  const _IncomingToast({
    required this.senderName,
    required this.text,
    required this.onOpen,
    required this.onClose,
  });

  @override
  State<_IncomingToast> createState() => _IncomingToastState();
}

class _IncomingToastState extends State<_IncomingToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), widget.onClose);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.senderName.isNotEmpty ? widget.senderName[0].toUpperCase() : '?';
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - t) * 40, 0),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF075985),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFFB923C),
                  child: Text(
                    initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      Text(
                        widget.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Открыть чат',
                  onPressed: widget.onOpen,
                  icon: const Icon(Icons.chat_bubble,
                      color: Colors.white, size: 20),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Закрыть',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close,
                      color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
