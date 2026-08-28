import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/segmented_selector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/utils/memorization_error_message.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../data/repositories/teacher_repository.dart';

class MemorizationEntrySheet extends StatefulWidget {
  const MemorizationEntrySheet({super.key, required this.student});
  final TeacherStudentModel student;

  @override
  State<MemorizationEntrySheet> createState() => _MemorizationEntrySheetState();
}

class _MemorizationEntrySheetState extends State<MemorizationEntrySheet> {
  int? _selectedSurah;
  int _amount = 1;
  MemorizationType? _selectedType;
  bool _isSaving = false;

  final _repo = TeacherRepository();

  /// The unit only becomes known once a type is picked, so the counter stays
  /// inert until then rather than collecting a number with no unit attached.
  void _onTypeChanged(MemorizationType? type) {
    setState(() {
      _selectedType = type;
      // Pages and hizbs are not interchangeable quantities; carrying the old
      // number across a unit switch would silently change what it means.
      _amount = 1;
    });
  }

  Future<void> _submit() async {
    if (_selectedSurah == null || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى تحديد السورة ونوع المراجعة',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.submitMemorization(
        studentId: widget.student.id,
        surahNumber: _selectedSurah!,
        amountDone: _amount,
        memorizationType: _selectedType!.apiValue,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _errorMessage(e),
              style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _errorMessage(Object error) => memorizationErrorMessage(error);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // keyboard-safe
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusLg),
          ),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              widget.student.fullName,
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: 12.h),

            AppCard(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedSurah,
                        isExpanded: true,
                        hint: Text(
                          'اختر السورة...',
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.inputPlaceholder,
                          ),
                        ),
                        items: kSurahs
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.number,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSurah = v),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  Text(
                    'نوع العرض',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  SegmentedSelector<MemorizationType>(
                    options: const [
                      SegmentOption(
                        value: MemorizationType.majorReview,
                        label: 'مراجعة كبرى',
                      ),
                      SegmentOption(
                        value: MemorizationType.minorReview,
                        label: 'مراجعة صغرى',
                      ),
                      SegmentOption(value: MemorizationType.hifz, label: 'حفظ'),
                    ],
                    selected: _selectedType,
                    onChanged: _onTypeChanged,
                  ),
                  SizedBox(height: 12.h),

                  Text(
                    // Revision is counted in hizbs, memorization in pages.
                    _selectedType?.amountLabel ?? 'العدد',
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
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: _selectedType == null
                              ? null
                              : () => setState(() {
                                  if (_amount < _selectedType!.maxAmount) {
                                    _amount++;
                                  }
                                }),
                          color: AppColors.primary,
                        ),
                        Expanded(
                          child: Text(
                            _selectedType == null ? '—' : '$_amount',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMdBold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _selectedType == null
                              ? null
                              : () => setState(() {
                                  if (_amount > 1) _amount--;
                                }),
                          color: AppColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),
            AppButton(
              label: 'تسجيل',
              variant: AppButtonVariant.gradient,
              icon: Icons.save_outlined,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
