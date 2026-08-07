import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_selector_field.dart';
import '../../../../features/data/repositories/absence_justification_repository.dart';
import 'justification_reason_fields.dart';

/// Inline form that lets a manager justify a student's absence or lateness.
///
/// A justification must attach to an existing attendance row (the backend
/// column is unique and required, and managers may not create attendance
/// themselves), so submitting resolves the student + date to that row first
/// and reports back when there is nothing to justify.
class JustificationFormCard extends StatefulWidget {
  const JustificationFormCard({
    super.key,
    required this.managerId,
    required this.students,
    this.onSaved,
  });

  /// Row id in the `managers` table, not the user id.
  final int managerId;

  /// Students in the manager's halaqas, as returned by
  /// `GET /managers/:id/students`.
  final List<dynamic> students;

  /// Called after a justification is stored, so the host can refresh counters.
  final VoidCallback? onSaved;

  @override
  State<JustificationFormCard> createState() => _JustificationFormCardState();
}

class _JustificationFormCardState extends State<JustificationFormCard> {
  final _repo = AbsenceJustificationRepository();
  final _reasonController = TextEditingController();
  final _dateController = TextEditingController();

  int? _selectedStudentId;
  DateTime? _selectedDate;
  String _reasonType = JustificationReasonFields.defaultReasonType;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  List<UserOption> get _studentOptions => widget.students
      .map((s) => UserOption.fromJson(s as Map<String, dynamic>))
      .toList();

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      locale: const Locale('fr'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  /// Finds the student's ABSENT/LATE attendance row for [date], or null.
  Future<Map<String, dynamic>?> _findAttendance(int studentId, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final res = await DioClient.instance.get(
      '${ApiEndpoints.attendance}/student/$studentId',
    );
    final records = res.data as List;

    for (final record in records) {
      final recordDate = record['date'] as String? ?? '';
      final status = record['status'] as String? ?? '';
      if (recordDate.startsWith(dateStr) &&
          (status == 'ABSENT' || status == 'LATE')) {
        return record as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final studentId = _selectedStudentId;
    final date = _selectedDate;
    final reason = _reasonController.text.trim();

    if (studentId == null) {
      _showMessage('يرجى اختيار الطالب', isError: true);
      return;
    }
    if (date == null) {
      _showMessage('يرجى اختيار تاريخ الغياب', isError: true);
      return;
    }
    final reasonError = JustificationReasonFields.validate(_reasonType, reason);
    if (reasonError != null) {
      _showMessage(reasonError, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final attendance = await _findAttendance(studentId, date);

      if (attendance == null) {
        _showMessage(
          'لا يوجد سجل غياب أو تأخر لهذا الطالب في هذا التاريخ',
          isError: true,
        );
        return;
      }

      final attendanceId = attendance['id'] as int;

      // One justification per attendance row; check before posting so the
      // manager gets a clear message instead of a constraint error.
      final existing = await _repo.getAllJustifications(studentId: studentId);
      if (existing.any((j) => j.attendanceId == attendanceId)) {
        _showMessage('هذا الغياب مبرر مسبقاً', isError: true);
        return;
      }

      await _repo.createJustification({
        'studentId': studentId,
        'attendanceId': attendanceId,
        'managerId': widget.managerId,
        ...JustificationReasonFields.payload(_reasonType, reason),
      });

      if (!mounted) return;
      _showMessage('تم حفظ العذر بنجاح');
      setState(() {
        _selectedStudentId = null;
        _selectedDate = null;
        _reasonType = 'ILLNESS';
        _reasonController.clear();
        _dateController.clear();
      });
      widget.onSaved?.call();
    } catch (e) {
      _showMessage(AbsenceJustificationRepository.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildHeader(),
          SizedBox(height: 20.h),
          UserSelectorField(
            label: 'الطالب *',
            hint: 'ابحث واختر الطالب',
            searchHint: 'ابحث باسم الطالب',
            emptyText: 'لا يوجد طالب مطابق',
            options: _studentOptions,
            selectedId: _selectedStudentId,
            onSelected: (o) => setState(() => _selectedStudentId = o.id),
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'تاريخ الغياب',
            hint: 'dd/mm/yyyy',
            readOnly: true,
            onTap: _pickDate,
            controller: _dateController,
            suffixIcon: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          JustificationReasonFields(
            reasonType: _reasonType,
            onReasonTypeChanged: (v) => setState(() => _reasonType = v),
            controller: _reasonController,
          ),
          SizedBox(height: 20.h),
          AppButton(
            label: 'حفظ العذر',
            variant: AppButtonVariant.gradient,
            icon: Icons.save_outlined,
            isLoading: _isSaving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: const BoxDecoration(
            color: AppColors.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.edit_calendar_outlined,
            color: AppColors.error,
            size: 20.w,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'تبرير غياب',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'تسجيل عذر غياب أو تأخر لطالب',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

}
