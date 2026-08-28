import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/confirm_logout_dialog.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'package:taqwa/features/data/repositories/manager_repository.dart';
import 'package:taqwa/features/data/repositories/absence_justification_repository.dart';
import '../widgets/justification_form_card.dart';

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  ConsumerState<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  final _managerRepo = ManagerRepository();
  final _justificationRepo = AbsenceJustificationRepository();
  Map<String, dynamic>? _stats;
  List<dynamic> _students = [];
  int? _managerId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // The manager's row id in the `managers` table rides on the auth user.
      // Don't look it up through GET /managers: that route is ADMIN-only and
      // 403s for a manager, which used to abort this whole load.
      final mgrId = ref.read(authProvider).user?.managerId;
      if (mgrId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final students = await _managerRepo.getManagerStudents(mgrId);
      final halaqas = await _managerRepo.getManagerHalaqas(mgrId);
      final justifications = await _justificationRepo.getAllJustifications(
        managerId: mgrId,
      );

      // Absences and latenesses still waiting for a justification — the same
      // list the "بانتظار التبرير" tab of the justifications page shows.
      final unjustified = await _justificationRepo.getUnjustified(mgrId);

      // Distinct parents across the manager's students. Derived from the
      // students payload because GET /parents needs MANAGE_ACCOUNTS, which
      // not every manager has.
      final parentIds = students
          .map((s) => s['parentId'])
          .where((id) => id != null)
          .toSet();

      if (mounted) {
        setState(() {
          _stats = {
            'halaqas': halaqas.length,
            'students': students.length,
            'parents': parentIds.length,
            'unjustified': unjustified.length,
            'justifications': justifications.length,
          };
          _managerId = mgrId;
          _students = students;
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
                child: CircularProgressIndicator(color: AppColors.primary),
              )
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
                            if (_managerId != null)
                              JustificationFormCard(
                                managerId: _managerId!,
                                students: _students,
                                onSaved: _loadData,
                              ),
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

  Future<void> _logout() async {
    final confirmed = await ConfirmLogoutDialog.show(context);
    if (!confirmed) return;
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Widget _buildAppBar(String name) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout, color: AppColors.error, size: 22.w),
            tooltip: 'تسجيل الخروج',
          ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً بك، $name',
                style: AppTextStyles.headlineLgMobile.copyWith(
                  color: AppColors.onPrimary,
                ),
                textAlign: TextAlign.start,
              ),
              SizedBox(height: 4.h),
              Text(
                'إليك نظرة عامة على نشاط المدرسة القرآنية اليوم',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.start,
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
        icon: Icons.group_outlined,
        iconColor: AppColors.secondary,
        iconBg: AppColors.secondaryContainer,
        value: '${_stats?['students'] ?? 0}',
        label: 'إجمالي الطلاب',
      ),
      _StatData(
        icon: Icons.family_restroom_outlined,
        iconColor: AppColors.primary,
        iconBg: AppColors.primaryContainer,
        value: '${_stats?['parents'] ?? 0}',
        label: 'إجمالي الأولياء',
      ),
      _StatData(
        icon: Icons.pending_actions_outlined,
        iconColor: AppColors.error,
        iconBg: AppColors.errorContainer,
        value: '${_stats?['unjustified'] ?? 0}',
        label: 'بانتظار التبرير',
        isAlert: true,
      ),
      _StatData(
        icon: Icons.fact_check_outlined,
        iconColor: AppColors.tertiary,
        iconBg: AppColors.tertiaryContainer,
        value: '${_stats?['justifications'] ?? 0}',
        label: 'تبريرات مسجلة',
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            textAlign: TextAlign.start,
          ),
        ],
      ),
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
