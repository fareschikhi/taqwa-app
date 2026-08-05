import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../admin_shell.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _isLoading = true;
  int _studentsCount = 0;
  int _teachersCount = 0;
  int _halaqasCount = 0;
  int _managersCount = 0;
  String _attendanceRate = '—';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final dio = DioClient.instance;
      final results = await Future.wait([
        dio.get(ApiEndpoints.students),
        dio.get(ApiEndpoints.teachers),
        dio.get(ApiEndpoints.halaqas),
        dio.get(ApiEndpoints.managers),
      ]);

      final students = results[0].data as List;
      final teachers = results[1].data as List;
      final halaqas = results[2].data as List;
      final managers = results[3].data as List;

      // Compute today's attendance rate from today's records
      String rate = '—';
      try {
        final today = DateTime.now();
        final dateStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final attRes = await dio.get(
          '${ApiEndpoints.attendance}/date',
          queryParameters: {'date': dateStr},
        );
        final attList = attRes.data as List;
        if (attList.isNotEmpty) {
          final present = attList.where((a) => a['status'] == 'PRESENT').length;
          rate = '${((present / attList.length) * 100).round()}%';
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _studentsCount = students.length;
          _teachersCount = teachers.length;
          _halaqasCount = halaqas.length;
          _managersCount = managers.length;
          _attendanceRate = rate;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = user?.fullName ?? 'المسؤول';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadStats,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.cardPadding,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 24.h),
                    _buildGreeting(name),
                    SizedBox(height: 24.h),
                    _buildKpiGrid(),
                    SizedBox(height: 24.h),
                    _buildChartAndActivity(),
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

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => AdminShellScope.of(context)?.openMenu(),
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: const Icon(
                  Icons.menu,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryContainer, width: 2),
              ),
              child: Icon(
                Icons.person,
                color: AppColors.onPrimaryContainer,
                size: 22.w,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'تقوى',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
      toolbarHeight: 56.h,
    );
  }

  Widget _buildGreeting(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'مرحباً بك، $name',
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'إليك نظرة عامة على أداء المعهد اليوم.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid() {
    if (_isLoading) {
      return SizedBox(
        height: 180.h,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.5,
      ),
      children: [
        StatCard(
          value: '$_studentsCount',
          label: 'إجمالي الطلاب',
          icon: Icons.group,
          iconColor: AppColors.primary,
          iconBgColor: AppColors.primaryContainer,
          bubbleColor: AppColors.primaryContainer,
        ),
        StatCard(
          value: '$_teachersCount',
          label: 'المعلمين',
          icon: Icons.badge,
          iconColor: AppColors.secondary,
          iconBgColor: AppColors.secondaryContainer,
          bubbleColor: AppColors.secondaryContainer,
        ),
        StatCard(
          value: _attendanceRate,
          label: 'نسبة الحضور',
          icon: Icons.check_circle,
          iconColor: AppColors.primary,
          iconBgColor: AppColors.primaryContainer,
          bubbleColor: AppColors.primaryContainer,
          valueColor: AppColors.primary,
        ),
        StatCard(
          value: '$_halaqasCount',
          label: 'الحلقات النشطة',
          icon: Icons.menu_book,
          iconColor: AppColors.tertiary,
          iconBgColor: AppColors.tertiaryContainer,
          bubbleColor: AppColors.tertiaryContainer,
        ),
        StatCard(
          value: '$_managersCount',
          label: 'المديرون',
          icon: Icons.manage_accounts,
          iconColor: AppColors.secondary,
          iconBgColor: AppColors.secondaryContainer,
          bubbleColor: AppColors.secondaryContainer,
        ),
      ],
    );
  }

  Widget _buildChartAndActivity() {
    return AppCard(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  'هذا الأسبوع',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'نسب الحضور ',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 120.h,
            child: _AttendanceBarChart(
              days: ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'],
              values: [0.92, 0.88, 0.96, 0.82, 0.90],
            ),
          ),
        ],
      ),
    );
  }
}

// class _ActivityItem extends StatelessWidget {
//   const _ActivityItem({
//     required this.title,
//     required this.subtitle,
//     required this.time,
//     required this.icon,
//     required this.iconBgColor,
//     required this.iconColor,
//   });

//   final String title, subtitle, time;
//   final IconData icon;
//   final Color iconBgColor, iconColor;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 title,
//                 style: AppTextStyles.labelMdBold.copyWith(
//                   color: AppColors.onSurface,
//                 ),
//               ),
//               SizedBox(height: 2.h),
//               Text(
//                 subtitle,
//                 style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
//               ),
//               SizedBox(height: 2.h),
//               Text(
//                 time,
//                 style: AppTextStyles.caption.copyWith(
//                   color: AppColors.outlineVariant,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         SizedBox(width: 12.w),
//         Container(
//           width: 36.w,
//           height: 36.w,
//           decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
//           child: Icon(icon, color: iconColor, size: 18.w),
//         ),
//       ],
//     );
//   }
// }

// class _BarChartWidget extends StatelessWidget {
//   const _BarChartWidget({required this.values, required this.labels});
//   final List<double> values;
//   final List<String> labels;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Expanded(
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: List.generate(values.length, (i) {
//               return Expanded(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 3.w),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.end,
//                     children: [
//                       Flexible(
//                         child: FractionallySizedBox(
//                           heightFactor: values[i],
//                           alignment: Alignment.bottomCenter,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               gradient: AppColors.brandGradient,
//                               borderRadius: BorderRadius.only(
//                                 topLeft: Radius.circular(4.r),
//                                 topRight: Radius.circular(4.r),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }),
//           ),
//         ),
//         Divider(color: AppColors.outlineVariant, height: 1),
//         SizedBox(height: 8.h),
//         Row(
//           children: labels.reversed
//               .map(
//                 (l) => Expanded(
//                   child: Text(
//                     l,
//                     style: AppTextStyles.caption.copyWith(
//                       color: AppColors.outline,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               )
//               .toList(),
//         ),
//       ],
//     );
//   }
// }

class _AttendanceBarChart extends StatelessWidget {
  const _AttendanceBarChart({required this.days, required this.values});
  final List<String> days;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              days.length,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${(values[i] * 100).round()}%',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: values[i],
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4.r),
                                topRight: Radius.circular(4.r),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Divider(color: AppColors.outlineVariant, height: 1),
        SizedBox(height: 8.h),
        Row(
          children: days.reversed
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
