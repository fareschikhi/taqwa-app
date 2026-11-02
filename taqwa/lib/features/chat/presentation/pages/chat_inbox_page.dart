import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/providers/chat_unread_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../data/models/chat/chat_inbox_item_model.dart';
import '../../../data/models/chat/chat_target.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../data/chat_push.dart';
import '../widgets/chat_inbox_tile.dart';
import 'chat_parent_picker_page.dart';
import 'chat_thread_page.dart';

/// Opens [item]'s thread for staff; shared by the inbox and the picker.
Future<void> openStaffThread(BuildContext context, ChatInboxItemModel item) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatThreadPage(
        target: ChatTarget.parent(item.parentId),
        title: item.parentName,
        subtitle: item.childrenLabel,
      ),
    ),
  );
}

/// The shared staff inbox: every parent thread this admin or manager may
/// see, most recent first, with their own unread counts.
class ChatInboxPage extends ConsumerStatefulWidget {
  const ChatInboxPage({super.key, this.leading});

  /// The top bar's start control. The admin shell has no app bar, so it
  /// passes its menu button here; when null, a pushed inbox gets a back
  /// button instead.
  final Widget? leading;

  @override
  ConsumerState<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends ConsumerState<ChatInboxPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<ChatInboxItemModel> _items = [];
  bool _loading = true;
  String? _error;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.inbox(search: _search.text);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ChatRepository.errorMessage(e);
      });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _open(ChatInboxItemModel item) async {
    await openStaffThread(context, item);
    if (!mounted) return;
    _load();
    ref.read(chatUnreadProvider.notifier).refresh();
  }

  Future<void> _newChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatParentPickerPage()),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    // A parent's message lands at the top of the list as it arrives.
    ref.listen(chatPushEventsProvider, (_, next) {
      final data = next.value;
      if (data != null && data['route'] == 'chat') _load();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
              child: Row(
                children: [
                  // Pushed from a manager's dashboard it goes back; as the
                  // admin's drawer page it opens the drawer instead.
                  if (widget.leading != null)
                    widget.leading!
                  else if (ModalRoute.of(context)?.canPop ?? false)
                    const BackButton(),
                  const Spacer(),
                  AppText(
                    'التقوى',
                    style: AppTextStyles.headlineMd.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    'المحادثات',
                    style: AppTextStyles.headlineLgMobile.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  AppText(
                    'رسائل أولياء الأمور إلى الإدارة. ردك يظهر لهم باسم الإدارة.',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SearchBarWidget(
                    hint: 'ابحث باسم ولي الأمر أو الطالب',
                    controller: _search,
                    onChanged: _onSearch,
                  ),
                  SizedBox(height: 12.h),
                  AppButton(
                    label: '+ محادثة جديدة مع ولي أمر',
                    variant: AppButtonVariant.secondary,
                    onPressed: _newChat,
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // One scrollable child in every state, so pulling down always reloads.
    Widget message(String text, Color color) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 48.h),
        Icon(
          Icons.forum_outlined,
          size: 48.w,
          color: AppColors.primaryFixedDim,
        ),
        SizedBox(height: 12.h),
        AppText(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: color),
        ),
      ],
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _error != null
          ? message(_error!, AppColors.error)
          : _items.isEmpty
          ? message(
              _search.text.trim().isEmpty
                  ? 'لا توجد محادثات بعد'
                  : 'لا توجد نتائج لهذا البحث',
              AppColors.onSurfaceVariant,
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (_, i) =>
                  ChatInboxTile(item: _items[i], onTap: () => _open(_items[i])),
            ),
    );
  }
}
