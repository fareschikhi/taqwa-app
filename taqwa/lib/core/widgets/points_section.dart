import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/points_adjust_dialog.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/core/widgets/points_stepper.dart';
import 'package:taqwa/features/data/models/points/points_summary_model.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';
import 'package:taqwa/features/shared/presentation/pages/points_history_page.dart';

/// Someone's points, for the staff screens that may change them: the card
/// (tap → history, with undo of the viewer's own manual entries), and with
/// [canAdjust] an `تعديل النقاط` button. Loads itself with [load] and reloads
/// after every change, so the total on screen is always the server's.
///
/// The server decides who may do what; [canAdjust] only hides a button that
/// would be refused.
class PointsSection extends ConsumerStatefulWidget {
  const PointsSection({
    super.key,
    required this.load,
    this.canAdjust = false,
    this.hideWhenUnavailable = true,
    this.title = 'النقاط',
    this.refreshKey,
    this.padding = EdgeInsets.zero,
    this.stepDelay = const Duration(milliseconds: 1500),
  });

  /// How long the − / + taps wait for more before they are saved as one
  /// entry. Tests shorten it.
  final Duration stepDelay;

  final Future<PointsSummaryModel> Function() load;
  final bool canAdjust;

  /// On a page where points are a side card (student details), loading or a
  /// refusal shows nothing. Where they are the whole point (the teacher
  /// sheet), it shows a spinner, then the error with a retry.
  final bool hideWhenUnavailable;

  final String title;

  /// Change it to reload, e.g. on the host page's pull-to-refresh.
  final Object? refreshKey;

  /// Around the section only while it shows, so a hidden one leaves no gap.
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<PointsSection> createState() => _PointsSectionState();
}

class _PointsSectionState extends ConsumerState<PointsSection> {
  final _repo = PointsRepository();
  PointsSummaryModel? _summary;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PointsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _reload();
  }

  /// Keeps the current card on screen while the next one loads.
  Future<void> _reload() async {
    if (_failed) setState(() => _failed = false);
    try {
      final summary = await widget.load();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      if (mounted && _summary == null) setState(() => _failed = true);
    }
  }

  Future<void> _openHistory(PointsSummaryModel summary) async {
    final user = ref.read(authProvider).user;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PointsHistoryPage(
          summary: summary,
          reload: widget.load,
          viewerId: user?.id,
          viewerIsAdmin: user?.role == UserRole.admin,
        ),
      ),
    );
    if (changed == true && mounted) await _reload();
  }

  Future<void> _adjust(int userId) async {
    final saved = await PointsAdjustDialog.show(
      context,
      onSubmit: (amount, reason) =>
          _repo.adjust(userId: userId, amount: amount, reason: reason),
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: AppText('تم تعديل النقاط')));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) {
      if (widget.hideWhenUnavailable) return const SizedBox.shrink();
      return _failed ? _buildError() : _buildLoading();
    }

    final userId = summary.userId;
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PointsBalanceCard(
            summary: summary,
            title: widget.title,
            onTap: () => _openHistory(summary),
          ),
          if (widget.canAdjust && userId != null) ...[
            SizedBox(height: 12.h),
            PointsStepper(
              total: summary.total,
              stepDelay: widget.stepDelay,
              onCommit: (delta) async {
                await _repo.adjust(userId: userId, amount: delta);
                if (mounted) await _reload();
              },
            ),
            SizedBox(height: 8.h),
            AppButton(
              label: 'تعديل النقاط',
              variant: AppButtonVariant.secondary,
              icon: Icons.tune,
              onPressed: () => _adjust(userId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading() => Padding(
    padding: EdgeInsets.symmetric(vertical: 24.h),
    child: const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    ),
  );

  Widget _buildError() => AppCard(
    padding: EdgeInsets.all(16.w),
    child: Column(
      children: [
        AppText(
          'تعذر تحميل النقاط',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 8.h),
        TextButton(
          onPressed: _reload,
          child: AppText(
            'إعادة المحاولة',
            style: AppTextStyles.button.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}
