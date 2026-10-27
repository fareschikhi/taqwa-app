import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/providers/auth_provider.dart';
import 'package:taqwa/core/widgets/app_logo.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/forgot_password_dialog.dart';

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

  Future<void> _login() async {
    // Runs the "required field" validators the form already declares. Without
    // this an empty form reaches the API, which answers "incorrect credentials"
    // instead of pointing at the field the user left blank.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final success = await ref
        .read(authProvider.notifier)
        .login(_phoneController.text.trim(), _passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Nothing is pushed on success: AuthGate watches the same state and swaps
    // this form for the right shell itself. Navigating here as well would
    // stack a second copy of that shell on top of the one already shown.
    if (!success) {
      final msg = ref.read(authProvider).errorMessage ?? 'حدث خطأ، حاول مجدداً';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(msg)));
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
                    AppLogo(height: 112.w),
                    SizedBox(height: 24.h),
                    AppText(
                      'التقوى',
                      style: AppTextStyles.displayLg.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    AppText(
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
                          AppText(
                            'تسجيل الدخول',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          AppText(
                            'أدخل بياناتك للوصول إلى حسابك',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          AppTextField(
                            label: 'رقم الهاتف أو البريد الإلكتروني',
                            hint: '05X XXX XXXX أو you@example.com',
                            controller: _phoneController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(
                              Icons.person_outline,
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
                              onPressed: () =>
                                  ForgotPasswordDialog.show(context),
                              child: AppText(
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
