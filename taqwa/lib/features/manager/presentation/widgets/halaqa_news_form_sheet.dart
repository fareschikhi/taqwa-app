import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/app_text_field.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_announcement_repository.dart';
import 'package:taqwa/features/data/repositories/halaqa_repository.dart';

/// Writes or edits one piece of halaqa news.
///
/// Pops with `true` once something is stored, so the caller reloads.
///
/// The halaqa list is fetched per role rather than passed in: a manager may
/// only post to halaqas assigned to them, and `GET /halaqas` is
/// ADMIN/TEACHER-only and 403s for them — the split [HalaqaRepository]
/// already documents.
class HalaqaNewsFormSheet extends StatefulWidget {
  const HalaqaNewsFormSheet({
    super.key,
    required this.isAdmin,
    this.managerId,
    this.existing,
  });

  final bool isAdmin;
  final int? managerId;
  final HalaqaAnnouncementModel? existing;

  static Future<bool> show(
    BuildContext context, {
    required bool isAdmin,
    int? managerId,
    HalaqaAnnouncementModel? existing,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HalaqaNewsFormSheet(
        isAdmin: isAdmin,
        managerId: managerId,
        existing: existing,
      ),
    );
    return saved ?? false;
  }

  @override
  State<HalaqaNewsFormSheet> createState() => _HalaqaNewsFormSheetState();
}

class _HalaqaNewsFormSheetState extends State<HalaqaNewsFormSheet> {
  final _repo = HalaqaAnnouncementRepository();
  final _halaqaRepo = HalaqaRepository();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  List<HalaqaModel> _halaqas = [];
  int? _halaqaId;
  bool _isLoadingHalaqas = true;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _bodyController.text = existing.body;
      _halaqaId = existing.halaqaId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHalaqas());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadHalaqas() async {
    try {
      final managerId = widget.managerId;
      final halaqas = widget.isAdmin || managerId == null
          ? await _halaqaRepo.getAllHalaqas()
          : await _halaqaRepo.getManagerHalaqas(managerId);
      if (!mounted) return;
      setState(() {
        _halaqas = halaqas;
        _isLoadingHalaqas = false;
        // One halaqa means there is nothing to choose.
        _halaqaId ??= halaqas.length == 1 ? halaqas.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingHalaqas = false);
      _showMessage(HalaqaRepository.errorMessage(e), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(message, textAlign: TextAlign.right),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Future<void> _submit() async {
    final halaqaId = _halaqaId;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (halaqaId == null) {
      _showMessage('اختر الحلقة', isError: true);
      return;
    }
    if (title.isEmpty) {
      _showMessage('أدخل عنوان الخبر', isError: true);
      return;
    }
    if (body.isEmpty) {
      _showMessage('أدخل نص الخبر', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await _repo.update(widget.existing!.id, {'title': title, 'body': body});
      } else {
        await _repo.create({
          'halaqaId': halaqaId,
          'title': title,
          'body': body,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      // The typed text stays in the fields: a dropped connection must not
      // cost the manager their announcement.
      _showMessage(HalaqaAnnouncementRepository.errorMessage(e), isError: true);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard while the news is being typed.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXl),
          ),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              AppText(
                _isEditing ? 'تعديل الخبر' : 'خبر جديد',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 20.h),
              _buildHalaqaSelector(),
              SizedBox(height: 16.h),
              AppTextField(
                label: 'العنوان',
                hint: 'غياب المعلم',
                controller: _titleController,
              ),
              SizedBox(height: 16.h),
              AppTextField(
                label: 'الخبر',
                hint: 'الحلقة معطلة غدا بسبب غياب المعلم',
                controller: _bodyController,
                maxLines: 4,
                minLines: 3,
              ),
              SizedBox(height: 20.h),
              AppButton(
                label: _isEditing ? 'حفظ التعديل' : 'نشر الخبر',
                variant: AppButtonVariant.gradient,
                icon: Icons.campaign_outlined,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHalaqaSelector() {
    if (_isLoadingHalaqas) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_halaqas.isEmpty) {
      return AppText(
        'لا توجد حلقات متاحة',
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        textAlign: TextAlign.end,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          'الحلقة',
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _halaqaId,
              isExpanded: true,
              // The halaqa of an existing announcement is not editable: moving
              // news between circles would surprise both audiences.
              onChanged: _isEditing
                  ? null
                  : (value) => setState(() => _halaqaId = value),
              hint: AppText(
                'اختر الحلقة',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              items: _halaqas
                  .map(
                    (h) => DropdownMenuItem<int>(
                      value: h.id,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppText(
                          h.name,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
