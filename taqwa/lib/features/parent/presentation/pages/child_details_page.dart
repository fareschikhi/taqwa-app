import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/selected_student_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/parent/parent_child_model.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class ChildDetailsPage extends ConsumerStatefulWidget {
  const ChildDetailsPage({super.key});

  @override
  ConsumerState<ChildDetailsPage> createState() => _ChildDetailsPageState();
}

class _ChildDetailsPageState extends ConsumerState<ChildDetailsPage> {
  final _repo = StudentRepository();
  bool _isLoading = true;
  int? _loadedChildId;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(selectedStudentProvider).selected?.id;
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
        _repo.getProfile(childId),
        _repo.getMemorizationProgress(childId),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0];
          _progress = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedStudentProvider).selected;

    ref.listen(selectedStudentProvider, (previous, next) {
      final id = next.selected?.id;
      if (id != null && id != _loadedChildId) _load(id);
    });

    if (child == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    final halaqa = _profile?['halaqa'] as Map<String, dynamic>?;
    final teacherName =
        ((halaqa?['teacher'] as Map<String, dynamic>?)?['user']
                as Map<String, dynamic>?)?['fullName']
            as String? ??
        'غير معين';
    final enrollmentDate = _formatDate(_profile?['enrollmentDate']);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(child.id),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, child, halaqa)),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBox(
                              label: 'المعلم',
                              value: teacherName,
                              icon: Icons.person_outline,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _InfoBox(
                              label: 'الحلقة',
                              value: (halaqa?['name'] as String?) ?? 'غير مسجل',
                              icon: Icons.menu_book_outlined,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBox(
                              label: 'تاريخ الالتحاق',
                              value: enrollmentDate,
                              icon: Icons.calendar_today_outlined,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _InfoBox(
                              label: 'المستوى',
                              value:
                                  (halaqa?['level'] as String?) ?? 'غير محدد',
                              icon: Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _buildMemorizationCard(),
                      SizedBox(height: 32.h),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemorizationCard() {
    final typeCounts =
        (_progress?['typeCounts'] as Map<String, dynamic>?) ?? {};
    final newCount = (typeCounts['MEMORIZING'] as num?)?.toInt() ?? 0;
    final minorCount = (typeCounts['SMALLREVISION'] as num?)?.toInt() ?? 0;
    final majorCount = (typeCounts['BIGREVISION'] as num?)?.toInt() ?? 0;

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            'تقدم الحفظ',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 16.h),
          _CountRow(label: 'حفظ', count: newCount, color: AppColors.primary),
          SizedBox(height: 10.h),
          _CountRow(
            label: 'مراجعة صغرى',
            count: minorCount,
            color: AppColors.secondary,
          ),
          SizedBox(height: 10.h),
          _CountRow(
            label: 'مراجعة كبرى',
            count: majorCount,
            color: AppColors.tertiary,
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'غير محدد';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return 'غير محدد';
    }
  }

  Widget _buildHeader(
    BuildContext context,
    ParentChildModel child,
    Map<String, dynamic>? halaqa,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.onPrimary,
                ),
              ),
              const Spacer(),
              AppText(
                'ملف الطالب',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    child.fullName,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                  AppText(
                    (halaqa?['name'] as String?) ?? 'غير مسجل في حلقة',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              AvatarWidget(
                avatarUrl: child.avatar,
                size: 64.w,
                backgroundColor: AppColors.onPrimary.withValues(alpha: 0.2),
                fallback: AppText(
                  child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                  style: AppTextStyles.headlineLgMobile.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppText(
                label,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(icon, size: 14.w, color: AppColors.primary),
            ],
          ),
          SizedBox(height: 6.h),
          AppText(
            value,
            style: AppTextStyles.labelMdBold.copyWith(
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: AppText(
            '$count',
            style: AppTextStyles.labelMdBold.copyWith(color: color),
          ),
        ),
        AppText(
          label,
          style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurface),
        ),
      ],
    );
  }
}
