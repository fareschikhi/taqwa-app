import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_announcement_repository.dart';
import 'package:taqwa/features/manager/presentation/widgets/halaqa_news_form_sheet.dart';

/// The full halaqa news history for whoever is signed in.
///
/// Reads /halaqa-announcements/mine, so the same page serves every role and
/// the scope stays on the server. A manager or admin also gets the compose
/// action and per-item edit and delete.
class HalaqaNewsPage extends StatefulWidget {
  const HalaqaNewsPage({
    super.key,
    this.canCompose = false,
    this.isAdmin = false,
    this.managerId,
  });

  final bool canCompose;
  final bool isAdmin;
  final int? managerId;

  @override
  State<HalaqaNewsPage> createState() => _HalaqaNewsPageState();
}

class _HalaqaNewsPageState extends State<HalaqaNewsPage> {
  final _repo = HalaqaAnnouncementRepository();

  List<HalaqaAnnouncementModel> _announcements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final announcements = await _repo.myAnnouncements();
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Unlike the dashboard card, this page has nothing else to show, so the
      // failure is stated rather than swallowed.
      setState(() {
        _error = HalaqaAnnouncementRepository.errorMessage(e);
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(message, textAlign: TextAlign.right),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Future<void> _compose({HalaqaAnnouncementModel? existing}) async {
    final saved = await HalaqaNewsFormSheet.show(
      context,
      isAdmin: widget.isAdmin,
      managerId: widget.managerId,
      existing: existing,
    );
    if (saved) await _load();
  }

  Future<void> _delete(HalaqaAnnouncementModel announcement) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      message: 'هل تريد حذف هذا الخبر؟ لا يمكن التراجع عن هذا الإجراء.',
    );
    if (!confirmed) return;

    try {
      await _repo.delete(announcement.id);
      _showMessage('تم حذف الخبر');
      await _load();
    } catch (e) {
      _showMessage(
        HalaqaAnnouncementRepository.errorMessage(e),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: AppText(
          'أخبار الحلقة',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        centerTitle: true,
      ),
      floatingActionButton: widget.canCompose
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _compose,
              child: Icon(Icons.add, color: AppColors.onPrimary),
            )
          : null,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final error = _error;
    if (error != null) {
      // Inside the RefreshIndicator, and scrollable even though it holds one
      // line: a reader has no compose button to retry from, so pulling down is
      // their only way back from a dropped connection without leaving the page.
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: AppText(
                error,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _announcements.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 120.h),
                AppText(
                  'لا توجد أخبار',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
              itemCount: _announcements.length,
              separatorBuilder: (_, _) => SizedBox(height: 12.h),
              itemBuilder: (_, i) => _buildItem(_announcements[i]),
            ),
    );
  }

  Widget _buildItem(HalaqaAnnouncementModel announcement) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              if (widget.canCompose) ...[
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18.w,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: () => _compose(existing: announcement),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18.w,
                    color: AppColors.error,
                  ),
                  onPressed: () => _delete(announcement),
                ),
              ],
              // Expanded, with no Spacer competing for the same flex space:
              // TextAlign.end already pushes a short title to the right, and
              // a Spacer here would have capped the title at half the row and
              // wrapped long ones early.
              Expanded(
                child: AppText(
                  announcement.title,
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          AppText(
            '${announcement.halaqaName} · ${announcement.formattedDate}',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.end,
          ),
          SizedBox(height: 8.h),
          AppText(
            announcement.body,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.end,
          ),
          if (announcement.authorName.isNotEmpty) ...[
            SizedBox(height: 8.h),
            AppText(
              announcement.authorName,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
              textAlign: TextAlign.end,
            ),
          ],
        ],
      ),
    );
  }
}
