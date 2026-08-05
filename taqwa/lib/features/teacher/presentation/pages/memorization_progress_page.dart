import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/segmented_selector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/progress_card.dart';

enum MemorizationType { hifz, minorReview, majorReview }

class MemorizationProgressPage extends StatefulWidget {
  const MemorizationProgressPage({super.key});

  @override
  State<MemorizationProgressPage> createState() =>
      _MemorizationProgressPageState();
}

class _MemorizationProgressPageState extends State<MemorizationProgressPage> {
  String? _selectedSurah;
  int _pagesNumber = 1;
  double _memQuality = 0.7;
  double _revQuality = 0.85;
  final _notesController = TextEditingController();
  bool _isSaving = false;
  String? _selectedStudent;

  final _surahs = [
    'البقرة',
    'آل عمران',
    'النساء',
    'المائدة',
    'الأنعام',
    'الأعراف',
    'الأنفال',
    'التوبة',
  ];
  final _students = [
    'عمر خالد',
    'يوسف طارق',
    'محمد الغامدي',
    'عبدالرحمن السالم',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {},
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(height: 20.h),
                      // Student selector
                      AppCard(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _SectionTitle(
                              icon: Icons.person_outline,
                              title: 'اختيار الطالب',
                            ),
                            SizedBox(height: 12.h),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd,
                                ),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedStudent,
                                  isExpanded: true,
                                  hint: Text(
                                    'اختر الطالب...',
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.inputPlaceholder,
                                    ),
                                  ),
                                  items: _students
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            s,
                                            style: AppTextStyles.bodyMd,
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedStudent = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Recitation details
                      AppCard(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Surah
                            Text(
                              'السورة',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd,
                                ),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSurah,
                                  isExpanded: true,
                                  hint: Text(
                                    'اختر السورة...',
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.inputPlaceholder,
                                    ),
                                  ),
                                  items: _surahs
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            'سورة $s',
                                            style: AppTextStyles.bodyMd,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedSurah = v),
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            // Ayah range
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'عدد الصفحات',
                                        style: AppTextStyles.labelMd.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            AppConstants.radiusMd,
                                          ),
                                          border: Border.all(
                                            color: AppColors.inputBorder,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                              onPressed: () => setState(
                                                () => _pagesNumber++,
                                              ),
                                              color: AppColors.primary,
                                            ),
                                            Expanded(
                                              child: Text(
                                                '$_pagesNumber',
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyMdBold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove,
                                                size: 18,
                                              ),
                                              onPressed: () => setState(() {
                                                if (_pagesNumber > 1) {
                                                  _pagesNumber--;
                                                }
                                              }),
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12.h),
                            // Ayah range
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'نوع العرض',
                                        style: AppTextStyles.labelMd.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      // SegmentedSelector<MemorizationType>(
                                      //   options: const [
                                      //     SegmentOption(
                                      //       value: MemorizationType.hifz,
                                      //       label: 'حفظ',
                                      //     ),
                                      //     SegmentOption(
                                      //       value: MemorizationType.minorReview,
                                      //       label: 'مراجعة صغرى',
                                      //     ),
                                      //     SegmentOption(
                                      //       value: MemorizationType.majorReview,
                                      //       label: 'مراجعة كبرى',
                                      //     ),
                                      //   ],
                                      //   selected: _selectedType,
                                      //   onChanged: (v) =>
                                      //       setState(() => _selectedType = v),
                                      // ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Quality sliders
                      AppCard(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _SectionTitle(
                              icon: Icons.tune_outlined,
                              title: 'جودة الأداء',
                            ),
                            SizedBox(height: 16.h),
                            _QualitySlider(
                              label: 'جودة الحفظ',
                              value: _memQuality,
                              color: AppColors.primary,
                              onChanged: (v) => setState(() => _memQuality = v),
                            ),
                            SizedBox(height: 16.h),
                            _QualitySlider(
                              label: 'جودة المراجعة',
                              value: _revQuality,
                              color: AppColors.secondary,
                              onChanged: (v) => setState(() => _revQuality = v),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Progress chart
                      AppCard(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _SectionTitle(
                              icon: Icons.pie_chart_outline,
                              title: 'تقدم القرآن الكريم',
                            ),
                            SizedBox(height: 16.h),
                            Center(
                              child: CircularProgressWidget(
                                percentage: 0.65,
                                label: 'من القرآن محفوظ',
                                size: 130.w,
                                strokeWidth: 14.w,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _LegendChip(
                                  label: 'جزء محفوظ',
                                  value: '19.5',
                                  color: AppColors.primary,
                                ),
                                _LegendChip(
                                  label: 'جزء متبقي',
                                  value: '10.5',
                                  color: AppColors.surfaceContainerHigh,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Notes
                      AppCard(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _SectionTitle(
                              icon: Icons.edit_note_outlined,
                              title: 'ملاحظات المعلم',
                            ),
                            SizedBox(height: 12.h),
                            TextField(
                              controller: _notesController,
                              maxLines: 4,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: AppTextStyles.bodyMd,
                              decoration: InputDecoration(
                                hintText: 'اكتب ملاحظاتك على أداء الطالب...',
                                hintStyle: AppTextStyles.labelMd.copyWith(
                                  color: AppColors.inputPlaceholder,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.inputBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.inputBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.inputFocusBorder,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: EdgeInsets.all(16.w),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      AppButton(
                        label: 'حفظ سجل التسميع',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.onSurface,
                ),
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'تسجيل تسميع جديد',
                  style: AppTextStyles.headlineLgMobile.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'أدخل تفاصيل جلسة التسميع والمراجعة.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualitySlider extends StatelessWidget {
  const _QualitySlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  String get _qualityLabel {
    if (value >= 0.9) return 'ممتاز';
    if (value >= 0.75) return 'جيد جداً';
    if (value >= 0.6) return 'جيد';
    if (value >= 0.5) return 'مقبول';
    return 'ضعيف';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: Text(
                _qualityLabel,
                style: AppTextStyles.labelSm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelMdBold.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: AppColors.surfaceContainerHigh,
            trackHeight: 6.h,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.r),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: 0,
            max: 1,
            divisions: 20,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(
        title,
        style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
      ),
      SizedBox(width: 8.w),
      Icon(icon, color: AppColors.primary, size: 20.w),
    ],
  );
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: AppTextStyles.labelMdBold.copyWith(color: AppColors.onSurface),
      ),
      SizedBox(width: 4.w),
      Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      SizedBox(width: 6.w),
      Container(
        width: 12.w,
        height: 12.w,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ],
  );
}
