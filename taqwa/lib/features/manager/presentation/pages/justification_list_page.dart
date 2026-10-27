import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../features/data/repositories/absence_justification_repository.dart';
import '../../../../features/data/models/absence_justification_model.dart';
import '../../../../features/data/models/unjustified_attendance_model.dart';
import '../widgets/justify_absence_sheet.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class JustificationListPage extends ConsumerStatefulWidget {
  const JustificationListPage({super.key});

  @override
  ConsumerState<JustificationListPage> createState() =>
      _JustificationListPageState();
}

class _JustificationListPageState extends ConsumerState<JustificationListPage> {
  final _repo = AbsenceJustificationRepository();
  List<AbsenceJustificationModel> _justifications = [];
  List<UnjustifiedAttendanceModel> _unjustified = [];
  bool _isLoading = true;
  int? _managerId;

  /// 0 = pending (unjustified), 1 = already justified.
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadJustifications();
  }

  Future<void> _loadJustifications() async {
    try {
      // GET /managers is ADMIN-only, so read the manager row id off the auth
      // user instead of looking it up.
      final managerId = ref.read(authProvider).user?.managerId;
      _managerId = managerId;

      final justifications = await _repo.getAllJustifications(
        managerId: managerId,
      );
      final unjustified = managerId == null
          ? <UnjustifiedAttendanceModel>[]
          : await _repo.getUnjustified(managerId);

      if (mounted) {
        setState(() {
          _justifications = justifications;
          _unjustified = unjustified;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadJustifications,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                child: Row(
                  children: [
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
                padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      'تبريرات الغياب',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    AppText(
                      'سجل تبريرات الغياب للطلاب',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    FilterChipGroup(
                      filters: [
                        'بانتظار التبرير (${_unjustified.length})',
                        'مبررة (${_justifications.length})',
                      ],
                      onChanged: (i) => setState(() => _filterIndex = i),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _buildList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final showingPending = _filterIndex == 0;
    final count = showingPending ? _unjustified.length : _justifications.length;

    if (count == 0) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 350.h,
          alignment: Alignment.center,
          child: _buildEmptyState(showingPending: showingPending),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (_, i) => showingPending
          ? _UnjustifiedCard(
              item: _unjustified[i],
              onTap: () => _justify(_unjustified[i]),
            )
          : _JustificationCard(item: _justifications[i]),
    );
  }

  Future<void> _justify(UnjustifiedAttendanceModel item) async {
    final managerId = _managerId;
    if (managerId == null) return;

    final saved = await JustifyAbsenceSheet.show(
      context,
      managerId: managerId,
      item: item,
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('تم حفظ العذر بنجاح', textAlign: TextAlign.right),
          backgroundColor: AppColors.primary,
        ),
      );
      await _loadJustifications();
    }
  }

  Widget _buildEmptyState({required bool showingPending}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              showingPending ? Icons.check_circle_outline : Icons.rule_outlined,
              size: 40.w,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          AppText(
            showingPending
                ? 'لا توجد غيابات بانتظار التبرير'
                : 'لا توجد تبريرات بعد',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 8.h),
          AppText(
            showingPending
                ? 'كل حالات الغياب والتأخر لدى طلابك مبررة'
                : 'ستظهر هنا تبريرات الغياب التي تضيفها',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// An absence or lateness still waiting for a justification.
class _UnjustifiedCard extends StatelessWidget {
  const _UnjustifiedCard({required this.item, required this.onTap});
  final UnjustifiedAttendanceModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusBg = item.isLate
        ? AppColors.tertiaryContainer
        : AppColors.errorContainer;
    final statusFg = item.isLate
        ? AppColors.onTertiaryContainer
        : AppColors.onErrorContainer;
    final initial = item.studentName.isNotEmpty ? item.studentName[0] : '؟';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      // Transparent Material so the tap ripple paints above the card's own
      // background instead of behind it.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Icon(
                  Icons.edit_calendar_outlined,
                  color: AppColors.primary,
                  size: 20.w,
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: AppText(
                    item.statusLabel,
                    style: AppTextStyles.labelSm.copyWith(color: statusFg),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      item.studentName,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    AppText(
                      item.formattedDate,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12.w),
                AvatarWidget(
                  avatarUrl: item.studentAvatar,
                  size: 44.w,
                  fallback: AppText(
                    initial,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JustificationCard extends StatelessWidget {
  const _JustificationCard({required this.item});
  final AbsenceJustificationModel item;

  @override
  Widget build(BuildContext context) {
    final attendance = item.attendance ?? {};
    final dateStr = attendance['date'] as String? ?? '';
    final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
    final formattedDate = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : 'غير محدد';

    final reasonColors = {
      'ILLNESS': AppColors.errorContainer,
      'OCCASION': AppColors.secondaryContainer,
      'OTHER': AppColors.tertiaryContainer,
    };
    final reasonFgColors = {
      'ILLNESS': AppColors.onErrorContainer,
      'OCCASION': AppColors.onSecondaryContainer,
      'OTHER': AppColors.onTertiaryContainer,
    };
    final bgColor =
        reasonColors[item.reasonType] ?? AppColors.tertiaryContainer;
    final fgColor =
        reasonFgColors[item.reasonType] ?? AppColors.onTertiaryContainer;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: AppText(
                  item.reasonLabel,
                  style: AppTextStyles.labelSm.copyWith(color: fgColor),
                ),
              ),
              Row(
                children: [
                  AppText(
                    item.studentName,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  AvatarWidget(
                    avatarUrl: item.studentAvatar,
                    size: 44.w,
                    fallback: AppText(
                      item.studentName.isNotEmpty ? item.studentName[0] : '؟',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      formattedDate,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppText(
                      'تاريخ الغياب',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  AppText(
                    item.notes!,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
