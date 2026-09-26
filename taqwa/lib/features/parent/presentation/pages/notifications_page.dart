import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/providers/selected_student_provider.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/models/notification_model.dart';
import 'package:taqwa/features/data/repositories/notification_repository.dart';

/// What the school has told this parent about the selected child, plus news
/// about no child in particular. Read-only apart from marking one as read,
/// which happens by tapping it.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key, this.onChanged});

  /// Lets the shell refresh its unread badge after a tap.
  final VoidCallback? onChanged;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _repo = NotificationRepository();
  List<NotificationModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final childId = ref.read(selectedStudentProvider).selected?.id;
    setState(() => _isLoading = true);
    try {
      final items = await _repo.getMine(studentId: childId);
      // Switching child mid-request: the newer load owns the list.
      if (!mounted ||
          childId != ref.read(selectedStudentProvider).selected?.id) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(NotificationRepository.errorMessage(e))),
      );
    }
  }

  Future<void> _markRead(NotificationModel item) async {
    if (item.isRead) return;
    try {
      await _repo.markRead(item.id);
      widget.onChanged?.call();
      await _load();
    } catch (_) {
      // Reading is a convenience; a failure here is not worth interrupting.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedStudentProvider, (previous, next) {
      if (next.selected?.id != previous?.selected?.id) _load();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
              child: AppText(
                'ملاحظات',
                style: AppTextStyles.headlineLgMobile.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: _items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: 120.h),
                                Center(
                                  child: AppText(
                                    'لا توجد ملاحظات',
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) => SizedBox(height: 10.h),
                              itemBuilder: (_, i) => _NotificationCard(
                                item: _items[i],
                                onTap: () => _markRead(_items[i]),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.surfaceContainerLowest
              : AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppText(
              item.title,
              style: AppTextStyles.bodyMdBold.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: 4.h),
            AppText(
              item.body,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
