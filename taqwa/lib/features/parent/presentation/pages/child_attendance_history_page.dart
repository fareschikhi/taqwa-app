import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/attendance_summary_model.dart';

class ChildAttendanceHistoryPage extends ConsumerStatefulWidget {
  const ChildAttendanceHistoryPage({super.key});

  @override
  ConsumerState<ChildAttendanceHistoryPage> createState() =>
      _ChildAttendanceHistoryPageState();
}

class _ChildAttendanceHistoryPageState
    extends ConsumerState<ChildAttendanceHistoryPage> {
  final _repo = StudentRepository();
  bool _isLoading = true;
  int? _loadedChildId;
  AttendanceSummaryModel? _summary;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(selectedChildProvider).selected?.id;
      if (id != null) _load(id);
    });
  }

  Future<void> _load(int childId) async {
    setState(() {
      _isLoading = true;
      _loadedChildId = childId;
    });
    try {
      final results = await Future.wait([
        _repo.getAttendanceSummary(childId),
        _repo.getAttendanceHistory(childId),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as AttendanceSummaryModel;
          _history = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider).selected;

    ref.listen(selectedChildProvider, (previous, next) {
      final id = next.selected?.id;
      if (id != null && id != _loadedChildId) _load(id);
    });

    if (child == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(child.id),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(height: 16.h),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const Spacer(),
                    Text(
                      'تقوى',
                      style: AppTextStyles.headlineMd.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  'سجل الحضور التفصيلي',
                  style: AppTextStyles.headlineLgMobile.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'سجلات حضور ${child.fullName} وغيابه.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 20.h),
                if (_isLoading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.h),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'حضور',
                          value: '${_summary?.present ?? 0}',
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _StatBox(
                          label: 'غياب',
                          value: '${_summary?.absent ?? 0}',
                          color: AppColors.error,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _StatBox(
                          label: 'نسبة الحضور',
                          value: '${_summary?.rate ?? 0}%',
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'السجل الزمني',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (_history.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Text(
                        'لا يوجد سجل حضور بعد',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ..._history.map(_buildRecordRow),
                ],
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> record) {
    final status = record['status'] as String?;
    final (label, color, icon) = switch (status) {
      'PRESENT' => ('حاضر', AppColors.present, Icons.check),
      'LATE' => ('متأخر', AppColors.late, Icons.schedule),
      _ => ('غائب', AppColors.absent, Icons.close),
    };

    String dateStr = '';
    try {
      final dt = DateTime.parse(record['date'].toString());
      dateStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      dateStr = (record['date'] ?? '').toString();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.02),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16.w),
          ),
          const Spacer(),
          Text(
            dateStr,
            style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
          ),
          SizedBox(width: 10.w),
          Text(
            label,
            style: AppTextStyles.labelMdBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
