import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../features/data/repositories/absence_justification_repository.dart';

/// Reason options offered to the manager, mapped onto [JustificationReasonType]
/// on the backend.
const _reasonTypes = <String, String>{
  'ILLNESS': 'مرض',
  'OCCASION': 'مناسبة (عائلية، اجتماعية)',
  'OTHER': 'أخرى',
};

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
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();
  final _dateController = TextEditingController();

  Map<String, dynamic>? _selectedStudent;
  DateTime? _selectedDate;
  String _reasonType = 'ILLNESS';
  bool _isPickerOpen = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredStudents {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.students;
    return widget.students.where((s) {
      final name = (s['user']?['fullName'] as String? ?? '').toLowerCase();
      final halaqa = (s['halaqa']?['name'] as String? ?? '').toLowerCase();
      return name.contains(q) || halaqa.contains(q);
    }).toList();
  }

  String _studentName(Map<String, dynamic> student) =>
      student['user']?['fullName'] as String? ?? 'غير معروف';

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
      locale: const Locale('ar'),
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
    final student = _selectedStudent;
    final date = _selectedDate;
    final reason = _reasonController.text.trim();

    if (student == null) {
      _showMessage('يرجى اختيار الطالب', isError: true);
      return;
    }
    if (date == null) {
      _showMessage('يرجى اختيار تاريخ الغياب', isError: true);
      return;
    }
    if (_reasonType == 'OTHER' && reason.isEmpty) {
      _showMessage('يرجى كتابة سبب الغياب', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final studentId = student['id'] as int;
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
        'reasonType': _reasonType,
        if (_reasonType == 'OTHER')
          'customReason': reason
        else if (reason.isNotEmpty)
          'notes': reason,
      });

      if (!mounted) return;
      _showMessage('تم حفظ العذر بنجاح');
      setState(() {
        _selectedStudent = null;
        _selectedDate = null;
        _reasonType = 'ILLNESS';
        _reasonController.clear();
        _searchController.clear();
        _dateController.clear();
        _isPickerOpen = false;
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
          _buildStudentPicker(),
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
          _buildReasonTypeField(),
          SizedBox(height: 16.h),
          AppTextField(
            label: _reasonType == 'OTHER' ? 'سبب الغياب *' : 'ملاحظات إضافية',
            hint: _reasonType == 'OTHER'
                ? 'يرجى توضيح العذر هنا...'
                : 'أضف أي تفاصيل أخرى (اختياري)',
            controller: _reasonController,
            maxLines: 3,
            minLines: 2,
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

  Widget _buildStudentPicker() {
    final selected = _selectedStudent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'الطالب *',
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 6.h),
        GestureDetector(
          onTap: () => setState(() => _isPickerOpen = !_isPickerOpen),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: _isPickerOpen
                    ? AppColors.inputFocusBorder
                    : AppColors.inputBorder,
                width: _isPickerOpen ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isPickerOpen ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.onSurfaceVariant,
                  size: 22.w,
                ),
                Expanded(
                  child: Text(
                    selected == null ? 'ابحث واختر الطالب' : _studentName(selected),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: selected == null
                          ? AppColors.inputPlaceholder
                          : AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isPickerOpen) ...[
          SizedBox(height: 8.h),
          _buildStudentPickerPanel(),
        ],
      ],
    );
  }

  Widget _buildStudentPickerPanel() {
    final results = _filteredStudents;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.inputBorder),
      ),
      padding: EdgeInsets.all(8.w),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الحلقة',
              hintStyle: AppTextStyles.labelMd.copyWith(
                color: AppColors.inputPlaceholder,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.onSurfaceVariant,
                size: 20.w,
              ),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.inputFocusBorder,
                  width: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 200.h),
            child: results.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Text(
                      'لا يوجد طالب مطابق',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final student = results[i] as Map<String, dynamic>;
                      final halaqa = student['halaqa']?['name'] as String?;
                      return InkWell(
                        onTap: () => setState(() {
                          _selectedStudent = student;
                          _isPickerOpen = false;
                          _searchController.clear();
                        }),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 10.h,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _studentName(student),
                                style: AppTextStyles.bodyMd.copyWith(
                                  color: AppColors.onSurface,
                                ),
                              ),
                              if (halaqa != null && halaqa.isNotEmpty)
                                Text(
                                  halaqa,
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'نوع العذر *',
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _reasonType,
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              icon: Icon(
                Icons.expand_more,
                color: AppColors.onSurfaceVariant,
                size: 22.w,
              ),
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
              onChanged: (v) {
                if (v != null) setState(() => _reasonType = v);
              },
              items: _reasonTypes.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, textAlign: TextAlign.right),
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
