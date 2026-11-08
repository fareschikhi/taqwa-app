import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../data/models/chat/chat_inbox_item_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../widgets/chat_grouped_list.dart';
import '../../../data/models/chat/chat_target.dart';
import 'chat_thread_page.dart';

/// Starts a conversation: the parents this staff member may write to. A
/// parent who already has a thread simply opens it.
class ChatParentPickerPage extends ConsumerStatefulWidget {
  const ChatParentPickerPage({super.key});

  @override
  ConsumerState<ChatParentPickerPage> createState() =>
      _ChatParentPickerPageState();
}

class _ChatParentPickerPageState extends ConsumerState<ChatParentPickerPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<ChatInboxItemModel> _parents = [];
  bool _loading = true;
  String? _error;

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
      final parents = await ref
          .read(chatRepositoryProvider)
          .pickableParents(search: _search.text);
      if (!mounted) return;
      setState(() {
        _parents = parents;
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

  /// Replaces the picker with the thread, so "back" returns to the inbox.
  void _open(ChatInboxItemModel item) {
    Navigator.pushReplacement(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        centerTitle: true,
        title: AppText(
          'محادثة جديدة',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: SearchBarWidget(
                hint: 'ابحث باسم ولي الأمر أو الطالب أو الحلقة',
                controller: _search,
                onChanged: _onSearch,
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
    final text =
        _error ??
        (_parents.isEmpty ? 'لا يوجد أولياء أمور يمكنك مراسلتهم' : null);
    if (text != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: AppText(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: _error != null
                  ? AppColors.error
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ChatGroupedList(
      items: _parents,
      onTap: _open,
      countLabel: parentCountLabel,
      byName: true,
    );
  }
}
