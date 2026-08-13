import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../admin/presentation/admin_shell.dart';
import '../../../teacher/presentation/teacher_shell.dart';
import '../../../parent/presentation/parent_shell.dart';
import '../../../manager/presentation/manager_shell.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // void _login(String role) {
  //   setState(() => _isLoading = true);
  //   Future.delayed(const Duration(seconds: 1), () {
  //     if (!mounted) return;
  //     setState(() => _isLoading = false);
  //     Widget dest;
  //     switch (role) {
  //       case 'admin':
  //         dest = const AdminShell();
  //       case 'teacher':
  //         dest = const TeacherShell();
  //       default:
  //         dest = const ParentShell();
  //     }
  //     Navigator.of(
  //       context,
  //     ).pushReplacement(MaterialPageRoute(builder: (_) => dest));
  //   });
  // }
  Future<void> _login() async {
    // Runs the "required field" validators the form already declares. Without
    // this an empty form reaches the API, which answers "incorrect credentials"
    // instead of pointing at the field the user left blank.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // admin 0000
    // parent 3001
    // teacher 2001
    // manager 1001
    // password: '123456',
    final success = await ref
        .read(authProvider.notifier)
        // .login('1001', '123456');
        .login(_phoneController.text.trim(), _passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final role = ref.read(authProvider).user?.role;
      final Widget dest = switch (role) {
        UserRole.admin => const AdminShell(),
        UserRole.teacher => const TeacherShell(),
        UserRole.manager => const ManagerShell(),
        _ => const ParentShell(),
      };
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => dest));
    } else {
      final msg = ref.read(authProvider).errorMessage ?? 'حدث خطأ، حاول مجدداً';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 48.h),
                    // Logo
                    Container(
                      width: 100.w,
                      height: 100.w,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusXl,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: AppColors.onPrimary,
                        size: 52.w,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'تقوى',
                      style: AppTextStyles.displayLg.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'منصة إدارة طلاب القرآن الكريم',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 48.h),
                    // Card
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusXl,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(18, 52, 59, 0.06),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'تسجيل الدخول',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'أدخل بياناتك للوصول إلى حسابك',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          AppTextField(
                            label: 'رقم الهاتف',
                            hint: '05X XXX XXXX',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              color: AppColors.onSurfaceVariant,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'هذا الحقل مطلوب'
                                : null,
                          ),
                          SizedBox(height: 16.h),
                          AppTextField(
                            label: 'كلمة المرور',
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: true,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.onSurfaceVariant,
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'هذا الحقل مطلوب'
                                : null,
                          ),
                          SizedBox(height: 8.h),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: () {},
                              child: Text(
                                'نسيت كلمة المرور؟',
                                style: AppTextStyles.labelMd.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          AppButton(
                            label: 'تسجيل الدخول',
                            variant: AppButtonVariant.gradient,
                            isLoading: _isLoading,
                            onPressed: () => _login(),
                          ),
                        ],
                      ),
                    ),
                    // SizedBox(height: 24.h),
                    // // Demo role switcher
                    // Text(
                    //   'الدخول التجريبي',
                    //   style: AppTextStyles.labelMd.copyWith(
                    //     color: AppColors.onSurfaceVariant,
                    //   ),
                    // ),
                    // SizedBox(height: 12.h),
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: _DemoRoleButton(
                    //         label: 'مدير',
                    //         icon: Icons.admin_panel_settings_outlined,
                    //         onTap: () => _login('admin'),
                    //       ),
                    //     ),
                    //     SizedBox(width: 8.w),
                    //     Expanded(
                    //       child: _DemoRoleButton(
                    //         label: 'معلم',
                    //         icon: Icons.school_outlined,
                    //         onTap: () => _login('teacher'),
                    //       ),
                    //     ),
                    //     SizedBox(width: 8.w),
                    //     Expanded(
                    //       child: _DemoRoleButton(
                    //         label: 'ولي أمر',
                    //         icon: Icons.family_restroom_outlined,
                    //         onTap: () => _login('parent'),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
