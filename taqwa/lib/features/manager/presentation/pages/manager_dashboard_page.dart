import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  ConsumerState<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState
    extends ConsumerState<ManagerDashboardPage> {
  Map<String, dynamic>? _stats;
  List<dynamic> _recentStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authState = ref.read(authProvider);
      final managerId = authState.user?.id;
      if (managerId == null) return;

      final dio = DioClient.instance;

      // get manager profile to find his id in managers table
      final managersRes = await dio.get(ApiEndpoints.managers);
      final allManagers = managersRes.data as List;
      final myManager = allManagers.firstWhere(
        (m) => m['user']?['id'] == managerId,
        orElse: () => null,
      );

      if (myManager == null) return;
      final int mgrId = myManager['id'];

      final studentsRes =
          await dio.get('${ApiEndpoints.managers}/$mgrId/students');
      final students = studentsRes.data as List;

      final halaqasRes =
          await dio.get('${ApiEndpoints.managers}/$mgrId/halaqas');
      final halaqas = halaqasRes.data as List;

      final justRes = await dio.get(
        ApiEndpoints.absenceJustifications,
        queryParameters: {'managerId': mgrId},
      );
      final justifications = justRes.data as List;

      // Count today's attendance for the manager's students
      int presentToday = 0;
      final total = students.length;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      for (final s in students) {
        try {
          final attRes = await dio.get(
            '${ApiEndpoints.attendance}/student/${s['id']}',
          );
          final attList = attRes.data as List;
          final todayAtt = attList.where((a) {
            final d = a['date'] as String? ?? '';
            return d.startsWith(dateStr) && a['status'] == 'PRESENT';
          });
          if (todayAtt.isNotEmpty) presentToday++;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _stats = {
            'halaqas': halaqas.length,
            'students': total,
            'attendanceRate':
                total > 0 ? ((presentToday / total) * 100).round() : 0,
            'pendingJustifications': justifications.length,
          };
          _recentStudents = students.take(5).toList();
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildAppBar(user?.fullName ?? 'المدير'),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20.h),
                            _buildWelcomeBanner(user?.fullName ?? 'المدير'),
                            SizedBox(height: 20.h),
                            _buildStatCards(),
                            SizedBox(height: 24.h),
                            _buildQuickActions(context),
                            SizedBox(height: 24.h),
                            _buildRecentStudents(context),
                            SizedBox(height: 32.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar(String name) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          const Spacer(),
          Text(
            'تقوى',
            style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(String name) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -10,
            child: Container(
              width: 90.w,
              height: 90.w,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'مرحباً بك، $name',
                style: AppTextStyles.headlineLgMobile.copyWith(
                  color: AppColors.onPrimary,
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 4.h),
              Text(
                'إليك نظرة عامة على نشاط المعهد اليوم',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final cards = [
      _StatData(
        icon: Icons.menu_book_outlined,
        iconColor: AppColors.secondary,
        iconBg: AppColors.secondaryContainer,
        value: '${_stats?['halaqas'] ?? 0}',
        label: 'حلقات مسندة',
      ),
      _StatData(
        icon: Icons.group_outlined,
        iconColor: AppColors.primary,
        iconBg: AppColors.primaryContainer,
        value: '${_stats?['students'] ?? 0}',
        label: 'إجمالي الطلاب',
      ),
      _StatData(
        icon: Icons.fact_check_outlined,
        iconColor: AppColors.tertiary,
        iconBg: AppColors.tertiaryContainer,
        value: '${_stats?['attendanceRate'] ?? 0}%',
        label: 'حضور اليوم',
      ),
      _StatData(
        icon: Icons.pending_actions_outlined,
        iconColor: AppColors.error,
        iconBg: AppColors.errorContainer,
        value: '${_stats?['pendingJustifications'] ?? 0}',
        label: 'تبريرات',
        isAlert: true,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.5,
      children: cards.map((c) => _buildStatCard(c)).toList(),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      padding: EdgeInsets.all(14.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.value,
                style: AppTextStyles.headlineMd.copyWith(
                  color: data.isAlert ? AppColors.error : AppColors.primary,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: data.iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: data.iconColor, size: 20.w),
              ),
            ],
          ),
          Text(
            data.label,
            style: AppTextStyles.labelMd.copyWith(
              color: data.isAlert
                  ? AppColors.error
                  : AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'إجراءات سريعة',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
          textAlign: TextAlign.right,
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
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
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
            childAspectRatio: 1.8,
            children: [
              _QuickActionBtn(
                icon: Icons.person_add_outlined,
                label: 'إضافة طالب',
                onTap: () {},
              ),
              _QuickActionBtn(
                icon: Icons.manage_accounts_outlined,
                label: 'تعديل طالب',
                onTap: () {},
              ),
              _QuickActionBtn(
                icon: Icons.rule_outlined,
                label: 'تبرير غياب',
                onTap: () {},
              ),
              _QuickActionBtn(
                icon: Icons.groups_outlined,
                label: 'عرض الطلاب',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentStudents(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {},
              child: Text(
                'عرض الكل',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
            Text(
              'أحدث الطلاب المضافين',
              style:
                  AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
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
          child: _recentStudents.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Center(
                    child: Text(
                      'لا يوجد طلاب بعد',
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                )
              : Column(
                  children: _recentStudents.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value as Map<String, dynamic>;
                    final user = s['user'] as Map<String, dynamic>? ?? {};
                    final fullName = user['fullName'] ?? '';
                    final isActive = user['isActive'] ?? true;
                    final initial =
                        fullName.isNotEmpty ? fullName[0] : '؟';
                    final halaqas = s['halaqas'] as List? ?? [];
                    final halaqaName = halaqas.isNotEmpty
                        ? (halaqas.first['halaqa']?['name'] ?? '')
                        : '';
                    final colors = [
                      AppColors.secondaryContainer,
                      AppColors.tertiaryContainer,
                      AppColors.primaryContainer,
                      AppColors.surfaceVariant,
                    ];
                    final fgColors = [
                      AppColors.onSecondaryContainer,
                      AppColors.onTertiaryContainer,
                      AppColors.onPrimaryContainer,
                      AppColors.onSurfaceVariant,
                    ];
                    final colorIdx = idx % colors.length;

                    return Container(
                      decoration: BoxDecoration(
                        border: idx < _recentStudents.length - 1
                            ? const Border(
                                bottom: BorderSide(
                                  color: AppColors.outlineVariant,
                                  width: 0.5,
                                ),
                              )
                            : null,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primaryContainer
                                    : AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusFull),
                              ),
                              child: Text(
                                isActive ? 'نشط' : 'غير نشط',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: isActive
                                      ? AppColors.onPrimaryContainer
                                      : AppColors.onErrorContainer,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  fullName,
                                  style: AppTextStyles.bodyMd.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                if (halaqaName.isNotEmpty)
                                  Text(
                                    halaqaName,
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 12.w),
                            Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                color: colors[colorIdx],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: AppTextStyles.headlineSm.copyWith(
                                    color: fgColors[colorIdx],
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _StatData {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final bool isAlert;

  const _StatData({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    this.isAlert = false,
  });
}

class _QuickActionBtn extends StatelessWidget {
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 22.w),
            SizedBox(height: 4.h),
            Text(
              label,
              style:
                  AppTextStyles.labelSm.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
