import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/chat_unread_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../data/models/chat/chat_message_model.dart';
import '../../../data/models/chat/chat_target.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../data/chat_push.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_message_actions.dart';
import '../widgets/chat_photo.dart';

/// How often an open thread asks for changes. Push makes most updates
/// instant; this catches the rest (a missed push, a colleague's edit).
const chatPollInterval = Duration(seconds: 5);

/// One conversation, for either side: the parent's own thread with
/// "الإدارة" ([ChatTarget.mine]) or a staff member's view of a parent's
/// thread ([ChatTarget.parent]).
class ChatThreadPage extends ConsumerStatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.target,
    required this.title,
    this.subtitle,
  });

  final ChatTarget target;
  final String title;
  final String? subtitle;

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  List<ChatMessageModel> _messages = [];
  DateTime? _serverTime;
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _polling = false;
  bool _left = false;
  String? _error;
  ChatMessageModel? _editing;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _pushes;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  bool get _staff => widget.target.isStaff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _pushes = ref.read(chatPushesProvider).listen((data) {
      if (isChatPushFor(data, widget.target.parentId)) _poll();
    });
    _load();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pushes?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// No polling while the app is in the background; catch up on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(chatPollInterval, (_) => _poll());
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.page(widget.target);
      if (!mounted) return;
      setState(() {
        _messages = page.messages;
        _serverTime = page.serverTime;
        _hasMore = page.hasMore;
        _loading = false;
      });
      _markRead();
    } catch (e) {
      if (!_handleForbidden(e) && mounted) {
        setState(() {
          _loading = false;
          _error = ChatRepository.errorMessage(e);
        });
      }
    }
  }

  /// New, edited and deleted messages since the last page.
  Future<void> _poll() async {
    final since = _serverTime;
    if (since == null || _polling || _left) return;
    _polling = true;
    try {
      final page = await _repo.page(widget.target, since: since);
      if (!mounted) return;
      final arrived = page.messages.any(
        (m) => !m.mine && !_messages.any((old) => old.id == m.id),
      );
      setState(() {
        _merge(page.messages);
        _serverTime = page.serverTime;
      });
      if (arrived) _markRead();
    } catch (e) {
      // A failed poll is retried on the next tick; only lost access matters.
      _handleForbidden(e);
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.page(
        widget.target,
        beforeId: _messages.first.id,
      );
      if (!mounted) return;
      setState(() {
        _merge(page.messages);
        _hasMore = page.hasMore;
      });
    } catch (e) {
      _handleForbidden(e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    // The list is reversed: the oldest messages are at the far end.
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Replaces messages we already have (edits, deletes), adds the rest.
  void _merge(List<ChatMessageModel> incoming) {
    final byId = {for (final m in _messages) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    _messages = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _markRead() async {
    try {
      await _repo.markRead(widget.target);
    } catch (_) {
      // Unread counts catch up on the next open.
    }
    if (mounted) ref.read(chatUnreadProvider.notifier).refresh();
  }

  /// A 403 means this user can no longer see the thread (chat permission
  /// revoked, halaqa reassigned): leave, and say why.
  bool _handleForbidden(Object e) {
    if (!ChatRepository.isForbidden(e) || !mounted || _left) return false;
    _left = true;
    _timer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).maybePop();
    messenger.showSnackBar(
      const SnackBar(content: Text('لم تعد تملك صلاحية هذه المحادثة')),
    );
    return true;
  }

  // ── Sending, editing, deleting ────────────────────────────────────────────

  Future<bool> _send(String text, XFile? photo) async {
    try {
      final editing = _editing;
      final message = editing != null
          ? await _repo.edit(editing.id, text)
          : await _repo.send(
              widget.target,
              body: text.isEmpty ? null : text,
              photo: photo,
            );
      if (!mounted) return true;
      setState(() {
        _merge([message]);
        _editing = null;
      });
      if (editing == null && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: AppConstants.animNormal,
          curve: Curves.easeOut,
        );
      }
      return true;
    } catch (e) {
      if (!_handleForbidden(e) && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ChatRepository.errorMessage(e))));
      }
      return false;
    }
  }

  Future<void> _onLongPress(ChatMessageModel message) async {
    final action = await showChatMessageActions(context, message);
    if (!mounted || action == null) return;
    if (action == ChatMessageAction.edit) {
      setState(() => _editing = message);
      return;
    }
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف الرسالة',
      message: 'ستُحذف هذه الرسالة عند الطرفين، ولا يمكن التراجع عن ذلك.',
    );
    if (!confirmed || !mounted) return;
    try {
      final deleted = await _repo.delete(message.id);
      if (mounted) setState(() => _merge([deleted]));
    } catch (e) {
      if (!_handleForbidden(e) && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ChatRepository.errorMessage(e))));
      }
    }
  }

  Future<XFile?> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              trailing: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: AppText(
                'اختيار من المعرض',
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMd,
              ),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            ListTile(
              trailing: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
              title: AppText(
                'التقاط صورة بالكاميرا',
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMd,
              ),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: AppConstants.pickedImageMaxDimension,
      maxHeight: AppConstants.pickedImageMaxDimension,
    );
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        centerTitle: true,
        title: Column(
          children: [
            AppText(
              widget.title,
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
              AppText(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          ChatComposer(
            hint: _staff ? 'الرد باسم الإدارة…' : 'اكتب رسالة…',
            onSend: _send,
            onPickPhoto: _pickPhoto,
            editingText: _editing?.body,
            onCancelEdit: () => setState(() => _editing = null),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.error),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: _load,
                child: AppText(
                  'إعادة المحاولة',
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 48.w,
                color: AppColors.primaryFixedDim,
              ),
              SizedBox(height: 12.h),
              AppText(
                _staff
                    ? 'لا توجد رسائل بعد. اكتب لولي الأمر باسم الإدارة.'
                    : 'راسل الإدارة هنا: تبرير غياب، استفسار، أو أي أمر يخص أبناءك.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final entries = _entries();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      itemCount: entries.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == entries.length) {
          return Padding(
            padding: EdgeInsets.all(12.w),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final entry = entries[i];
        if (entry is DateTime) return _DaySeparator(day: entry);
        final message = entry as ChatMessageModel;
        return ChatBubble(
          key: ValueKey(message.id),
          message: message,
          staffView: _staff,
          onLongPress: () => _onLongPress(message),
          photo: message.hasImage
              ? ChatPhoto(url: _repo.photoUrl(message.id))
              : null,
        );
      },
    );
  }

  /// Messages with a day header before each new day, newest first (the list
  /// is reversed so it opens at the bottom).
  List<Object> _entries() {
    final out = <Object>[];
    DateTime? day;
    for (final m in _messages) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (d != day) {
        out.add(d);
        day = d;
      }
      out.add(m);
    }
    return out.reversed.toList();
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'اليوم'
        : day == today.subtract(const Duration(days: 1))
        ? 'أمس'
        : '${day.day}/${day.month}/${day.year}';
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        ),
        child: AppText(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
