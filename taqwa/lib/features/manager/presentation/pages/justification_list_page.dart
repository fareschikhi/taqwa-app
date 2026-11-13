import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/halaqa_order_provider.dart';
import '../../../../core/utils/halaqa_order.dart';
import '../../../../core/widgets/halaqa_order_sheet.dart';
import '../../../../core/utils/student_grouping.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/widgets/halaqa_group_section.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../features/data/repositories/absence_justification_repository.dart';
import '../../../../features/data/models/absence_justification_model.dart';
import '../../../../features/data/models/unjustified_attendance_model.dart';
import '../widgets/justify_absence_sheet.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class JustificationListPage extends ConsumerStatefulWidget {
  const JustificationListPage({
    super.key,
    this.filter,
    this.allHalaqas = false,
    this.leading,
  });

  /// Shared with the dashboard, whose cards pick which list opens here.
  final ValueNotifier<int>? filter;

  /// The admin's read-only view: every halaqa, and each excuse names the
  /// manager who recorded it. Admins have no manager row, and an excuse
  /// must belong to one, so pending rows cannot be justified from here.
  final bool allHalaqas;

  /// Drawn before the title, such as the admin drawer's menu button.
  final Widget? leading;

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

  /// Halaqa ids the manager folded away, kept across reloads and both tabs.
  final Set<int?> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _filterIndex = widget.filter?.value ?? 0;
    widget.filter?.addListener(_onFilterChanged);
    _loadJustifications();
  }

  @override
  void dispose() {
    widget.filter?.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    final index = widget.filter!.value;
    if (index != _filterIndex) setState(() => _filterIndex = index);
  }

  /// A chip tap writes back to the shared filter too, so a dashboard card
  /// asking for the list already chosen here still registers as a change.
  void _selectFilter(int index) {
    setState(() => _filterIndex = index);
    widget.filter?.value = index;
  }

  Future<void> _loadJustifications() async {
    try {
      // GET /managers is ADMIN-only, so read the manager row id off the auth
      // user instead of looking it up.
      final managerId = widget.allHalaqas
          ? null
          : ref.read(authProvider).user?.managerId;
      _managerId = managerId;

      // Both lists go out together; with no manager id they span the school.
      final justificationsCall = _repo.getAllJustifications(
        managerId: managerId,
      );
      final unjustifiedCall = widget.allHalaqas
          ? _repo.getUnjustified()
          : managerId == null
          ? Future.value(<UnjustifiedAttendanceModel>[])
          : _repo.getUnjustified(managerId: managerId);
      final justifications = await justificationsCall;
      final unjustified = await unjustifiedCall;

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
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (widget.leading != null) widget.leading!,
                        SizedBox(width: 12.w),
                        Expanded(
                          child: AppText(
                            'تبريرات الغياب',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.headlineLgMobile.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppText(
                      widget.allHalaqas
                          ? 'غيابات الطلاب وتبريراتها في كل الحلقات'
                          : 'سجل تبريرات الغياب للطلاب',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    FilterChipGroup(
                      // The group keeps its own selection, so it is rebuilt
                      // when a dashboard card changes the filter from outside.
                      key: ValueKey(_filterIndex),
                      initialIndex: _filterIndex,
                      filters: [
                        'بانتظار التبرير (${_unjustified.length})',
                        'مبررة (${_justifications.length})',
                      ],
                      onChanged: _selectFilter,
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

    // A manager can cover several halaqas, so rows are split by circle;
    // inside each one the newest-first order from the API is kept.
    final List<HalaqaBucket<Object>> buckets = showingPending
        ? groupByHalaqa<UnjustifiedAttendanceModel>(
            _unjustified,
            halaqaIdOf: (item) => item.halaqaId,
            halaqaNameOf: (item) => item.halaqaName,
          )
        : groupByHalaqa<AbsenceJustificationModel>(
            _justifications,
            halaqaIdOf: (item) => item.halaqaId,
            halaqaNameOf: (item) => item.halaqaName,
          );
    final groups = applyHalaqaOrder(
      buckets,
      ref.watch(halaqaOrderProvider),
      idOf: (g) => g.halaqaId,
    );
    final halaqas = reorderableHalaqas<HalaqaBucket<Object>>(
      groups,
      idOf: (g) => g.halaqaId,
      nameOf: (g) => g.name,
    );

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      itemCount: groups.length,
      separatorBuilder: (_, _) => SizedBox(height: 20.h),
      itemBuilder: (_, i) {
        final group = groups[i];
        return HalaqaGroupSection(
          title: group.name,
          count: group.items.length,
          countLabel: caseCountLabel(group.items.length),
          isUnassigned: group.isUnassigned,
          isExpanded: !_collapsed.contains(group.halaqaId),
          onReorder: halaqas == null
              ? null
              : () => reorderHalaqas(context, ref, halaqas),
          onToggle: () => setState(() {
            if (!_collapsed.remove(group.halaqaId)) {
              _collapsed.add(group.halaqaId);
            }
          }),
          children: [
            for (final (j, item) in group.items.indexed) ...[
              if (j > 0) SizedBox(height: 12.h),
              if (item is UnjustifiedAttendanceModel)
                _UnjustifiedCard(
                  item: item,
                  onTap: widget.allHalaqas ? null : () => _justify(item),
                )
              else if (item is AbsenceJustificationModel)
                _JustificationCard(item: item, showManager: widget.allHalaqas),
            ],
          ],
        );
      },
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
                ? widget.allHalaqas
                      ? 'كل حالات الغياب والتأخر لدى الطلاب مبررة'
                      : 'كل حالات الغياب والتأخر لدى طلابك مبررة'
                : widget.allHalaqas
                ? 'ستظهر هنا تبريرات الغياب التي يسجلها المديرون'
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

/// A section header counts absence cases, not students: one student can be
/// absent on several days. Arabic reads one, two, 3–10 and 11+ differently.
@visibleForTesting
String caseCountLabel(int count) {
  if (count == 1) return 'حالة واحدة';
  if (count == 2) return 'حالتان';
  if (count <= 10) return '$count حالات';
  return '$count حالة';
}

/// An absence or lateness still waiting for a justification.
class _UnjustifiedCard extends StatelessWidget {
  const _UnjustifiedCard({required this.item, this.onTap});
  final UnjustifiedAttendanceModel item;

  /// Null in the admin's read-only view: the card is shown, not actionable.
  final VoidCallback? onTap;

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
            color: Color.fromRGBO(0, 40, 0, 0.04),
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
                if (onTap != null) ...[
                  Icon(
                    Icons.edit_calendar_outlined,
                    color: AppColors.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                ],
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
  const _JustificationCard({required this.item, this.showManager = false});
  final AbsenceJustificationModel item;

  /// Names who recorded the excuse, for a list that spans several managers.
  final bool showManager;

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
            color: Color.fromRGBO(0, 40, 0, 0.04),
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
                if (showManager && item.managerName != null) ...[
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: AppText(
                          item.managerName!,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AppText(
                        'سجّله',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
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
