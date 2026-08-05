import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';


class EvaluationPage extends StatefulWidget {
  const EvaluationPage({super.key});

  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  final Map<String, double> _scores = {
    'الحفظ': 0.8,
    'التجويد': 0.75,
    'الطلاقة': 0.9,
    'الانضباط': 0.85,
  };
  String? _selectedStudent;
  bool _isSaving = false;

  final _students = ['عمر خالد', 'يوسف طارق', 'محمد الغامدي', 'عبدالرحمن السالم'];

  double get _totalScore =>
      _scores.values.fold(0.0, (a, b) => a + b) / _scores.length;

  String get _totalLabel {
    if (_totalScore >= 0.9) return 'ممتاز';
    if (_totalScore >= 0.75) return 'جيد جداً';
    if (_totalScore >= 0.6) return 'جيد';
    if (_totalScore >= 0.5) return 'مقبول';
    return 'ضعيف';
  }

  Color get _totalColor {
    if (_totalScore >= 0.75) return AppColors.primary;
    if (_totalScore >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 8.h, 16.w, 0),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_ios),
                  ),
                  const Spacer(),
                  Text('تقوى', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
                ]),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('تقييم الطالب',
                        style: AppTextStyles.headlineLgMobile.copyWith(color: AppColors.onSurface)),
                    Text('قيّم أداء الطالب في جوانب التلاوة المختلفة.',
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    SizedBox(height: 20.h),
                    // Student selector
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStudent,
                          isExpanded: true,
                          hint: Text('اختر الطالب...',
                              style: AppTextStyles.labelMd.copyWith(color: AppColors.inputPlaceholder)),
                          items: _students.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: AppTextStyles.bodyMd, textAlign: TextAlign.end),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedStudent = v),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Criteria cards
                    ..._scores.entries.map((e) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: _EvalCriteriaCard(
                        label: e.key,
                        value: e.value,
                        onChanged: (v) => setState(() => _scores[e.key] = v),
                      ),
                    )),
                    SizedBox(height: 8.h),
                    // Total score card
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [AppColors.primaryContainer, AppColors.surfaceContainerLowest],
                        ),
                        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                        boxShadow: const [BoxShadow(
                          color: Color.fromRGBO(18, 52, 59, 0.08), blurRadius: 20, offset: Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${(_totalScore * 100).round()}%',
                                style: AppTextStyles.displayLg.copyWith(
                                    color: _totalColor, fontWeight: FontWeight.w700)),
                            Text('من المجموع الكلي',
                                style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('التقييم الإجمالي',
                                style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface)),
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: _totalColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                                border: Border.all(color: _totalColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(_totalLabel,
                                  style: AppTextStyles.headlineSm.copyWith(
                                      color: _totalColor, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    AppButton(
                      label: 'حفظ التقييم',
                      variant: AppButtonVariant.gradient,
                      icon: Icons.star_outlined,
                      isLoading: _isSaving,
                      onPressed: () {
                        setState(() => _isSaving = true);
                        final navigator = Navigator.of(context);
                        Future.delayed(const Duration(seconds: 1), () {
                          if (!mounted) return;
                          setState(() => _isSaving = false);
                          navigator.pop();
                        });
                      },
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
}

class _EvalCriteriaCard extends StatelessWidget {
  const _EvalCriteriaCard({required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  String get _scoreLabel {
    if (value >= 0.9) return 'ممتاز';
    if (value >= 0.75) return 'جيد جداً';
    if (value >= 0.6) return 'جيد';
    if (value >= 0.5) return 'مقبول';
    return 'ضعيف';
  }

  Color get _color {
    if (value >= 0.75) return AppColors.primary;
    if (value >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: Text(_scoreLabel,
                  style: AppTextStyles.labelSm.copyWith(color: _color, fontWeight: FontWeight.w700)),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: AppTextStyles.labelMdBold.copyWith(color: AppColors.onSurface)),
              SizedBox(width: 6.w),
              Text('${(value * 100).round()}%',
                  style: AppTextStyles.labelMdBold.copyWith(color: _color)),
            ]),
          ]),
          SizedBox(height: 8.h),
          Row(
            children: List.generate(5, (i) {
              final threshold = (i + 1) * 0.2;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(threshold),
                  child: Container(
                    height: 36.h,
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    decoration: BoxDecoration(
                      color: value >= threshold
                          ? _color
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

