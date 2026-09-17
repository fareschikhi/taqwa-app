import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../admin_shell.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// The admin's reports tab.
///
/// Everything below the heading used to be a mockup: a fixed 1,240 students,
/// a 94% attendance figure, a donut split 65/35 and four invented teachers
/// with invented scores. None of it was ever read from the server, and an
/// admin had no way to tell it apart from the real figures on the dashboard
/// next door. It is an empty state until the numbers behind it are real —
/// an unbuilt page is a smaller problem than a convincing wrong one.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => AdminShellScope.of(context)?.openMenu(),
                        child: Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMd,
                            ),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Spacer(),
                      AppText(
                        'التقارير والإحصاءات',
                        style: AppTextStyles.headlineLgMobile.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AppText(
                      'تتبع أداء المدرسة القرآنية بشكل دوري',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insert_chart_outlined,
                      size: 56.w,
                      color: AppColors.outline,
                    ),
                    SizedBox(height: 16.h),
                    AppText(
                      'التقارير قيد الإنشاء',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    AppText(
                      'ستظهر هنا عندما تُربط بأرقام المدرسة الحقيقية. '
                      'حتى ذلك الحين، أرقام الحضور والحلقات في الصفحة '
                      'الرئيسية.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
