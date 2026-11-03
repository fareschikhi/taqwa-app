import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/features/data/models/points/point_entry_model.dart';
import 'package:taqwa/features/data/models/points/points_summary_model.dart';

/// Every entry behind a points total. [summary] is passed in rather than
/// reloaded, as on the fines statement, so the list always agrees with the
/// total that was just tapped.
///
/// With [reload], manual entries the viewer may undo (see
/// [canUndoPointEntry]) get a delete button; after a removal the page shows
/// [reload]'s fresh summary and, when closed, pops `true` so the card behind
/// it can refresh too. Without [reload] the page is read-only.
class PointsHistoryPage extends StatefulWidget {
  const PointsHistoryPage({
    super.key,
    required this.summary,
    this.title = 'سجل النقاط',
    this.reload,
    this.viewerId,
    this.viewerIsAdmin = false,
  });

  final PointsSummaryModel summary;
  final String title;
  final Future<PointsSummaryModel> Function()? reload;
  final int? viewerId;
  final bool viewerIsAdmin;

  @override
  State<PointsHistoryPage> createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage> {
  final _repo = PointsRepository();
  late PointsSummaryModel _summary = widget.summary;
  bool _changed = false;
  int? _removingId;

  bool _canUndo(PointEntryModel entry) =>
      widget.reload != null &&
      canUndoPointEntry(
        entry,
        viewerId: widget.viewerId,
        viewerIsAdmin: widget.viewerIsAdmin,
      );

  Future<void> _undo(PointEntryModel entry) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف التعديل',
      message: 'سيُحذف هذا التعديل من النقاط.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _removingId = entry.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.remove(entry.id);
    } catch (e) {
      if (mounted) setState(() => _removingId = null);
      messenger.showSnackBar(
        SnackBar(content: AppText(PointsRepository.errorMessage(e))),
      );
      return;
    }

    // The delete is done whatever happens next: say so, and only then try to
    // refresh. A failed refresh must not read as a failed delete.
    _changed = true;
    messenger.showSnackBar(const SnackBar(content: AppText('تم حذف التعديل')));
    PointsSummaryModel next;
    try {
      next = await widget.reload!();
    } catch (_) {
      // Offline after the delete: drop the row by hand. The card behind the
      // page reloads on the way back anyway.
      next = PointsSummaryModel(
        userId: _summary.userId,
        total: _summary.total - entry.amount,
        entries: _summary.entries.where((e) => e.id != entry.id).toList(),
      );
    }
    if (!mounted) return;
    setState(() {
      _summary = next;
      _removingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final entries = summary.entries;
    final title = widget.title;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: AppText(
            title,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.onSurface),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppText(
                    'المجموع: ${formatPoints(summary.total)}',
                    style: AppTextStyles.bodyMdBold.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: AppText(
                          'لا توجد نقاط مسجلة بعد',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => SizedBox(height: 8.h),
                        itemBuilder: (_, i) => _buildEntry(entries[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(PointEntryModel entry) {
    final date = entry.displayDate;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final by = entry.createdByName;

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              AppText(
                formatSignedPoints(entry.amount),
                style: AppTextStyles.labelMdBold.copyWith(
                  color: pointsColor(entry.amount),
                ),
              ),
              if (_canUndo(entry)) ...[
                SizedBox(width: 8.w),
                _removingId == entry.id
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : IconButton(
                        tooltip: 'حذف التعديل',
                        onPressed: _removingId == null
                            ? () => _undo(entry)
                            : null,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20.w,
                          color: AppColors.error,
                        ),
                      ),
              ],
              const Spacer(),
              Flexible(
                child: AppText(
                  entry.label,
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          AppText(
            dateText,
            style: AppTextStyles.labelMd.copyWith(color: AppColors.outline),
          ),
          if (by != null && by.isNotEmpty) ...[
            SizedBox(height: 2.h),
            AppText(
              'بواسطة $by',
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
