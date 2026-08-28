import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/student_grouping.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/halaqa_group_section.dart';
import '../../../../features/data/models/student/student_model.dart';
import '../../../../features/data/repositories/student_repository.dart';
import '../../../../features/data/repositories/manager_repository.dart';
import '../../../shared/presentation/pages/student_form_page.dart';

class ManagerStudentsPage extends ConsumerStatefulWidget {
  const ManagerStudentsPage({super.key});

  @override
  ConsumerState<ManagerStudentsPage> createState() =>
      _ManagerStudentsPageState();
}

class _ManagerStudentsPageState extends ConsumerState<ManagerStudentsPage> {
  List<Map<String, dynamic>> _students = [];
  List<HalaqaGroup> _groups = [];
  bool _isLoading = true;
  int _filterIndex = 0;

  /// Halaqa ids the user folded away, kept across reloads and filter changes.
  final Set<int?> _collapsed = {};
  final _searchController = TextEditingController();
  final _studentRepo = StudentRepository();
  final _managerRepo = ManagerRepository();

  /// Opens the shared student form: [student] null creates, otherwise edits
  /// that row. The manager id scopes the halaqa options to the ones they own.
  Future<void> _openForm(Map<String, dynamic>? student) async {
    final mgrId = ref.read(authProvider).user?.managerId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormPage(
          student: student == null ? null : StudentModel.fromJson(student),
          managerId: mgrId,
        ),
      ),
    );
    if (mounted) _loadStudents();
  }

  Future<void> _deleteStudent(int id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف الطالب',
      message:
          'سيتم حذف حساب الطالب وجميع سجلاته نهائياً. '
          'لا يمكن التراجع عن هذا الإجراء.',
    );
    if (!confirmed) return;
    try {
      await _studentRepo.deleteStudent(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الطالب بنجاح')));
      _loadStudents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StudentRepository.errorMessage(e))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final mgrId = ref.read(authProvider).user?.managerId;
      if (mgrId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final students = await _managerRepo.getManagerStudents(mgrId);

      if (mounted) {
        setState(() {
          _students = students;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    var list = _students.where((s) {
      final user = s['user'] as Map<String, dynamic>? ?? {};
      final name = (user['fullName'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      return q.isEmpty || name.contains(q) || phone.contains(q);
    }).toList();

    if (_filterIndex == 1) {
      list = list
          .where((s) => (s['user']?['isActive'] ?? true) == true)
          .toList();
    } else if (_filterIndex == 2) {
      list = list
          .where((s) => (s['user']?['isActive'] ?? true) == false)
          .toList();
    }
    _groups = groupStudentsByHalaqa(list);
  }

  /// A collapsed section would hide a search hit, so searching overrides the
  /// folded state without discarding it.
  bool _isExpanded(HalaqaGroup group) =>
      _searchController.text.trim().isNotEmpty ||
      !_collapsed.contains(group.halaqaId);

  @override
  Widget build(BuildContext context) {
    final activeCount = _students
        .where((s) => s['user']?['isActive'] == true)
        .length;
    final inactiveCount = _students.length - activeCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadStudents,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      'تقوى',
                      style: AppTextStyles.headlineMd.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة الطلاب',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'متابعة طلاب حلقاتك المسندة',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (ref.watch(authProvider).user?.canManageAccounts ??
                        false) ...[
                      AppButton(
                        label: 'إضافة طالب جديد',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.person_add,
                        onPressed: () => _openForm(null),
                      ),
                      SizedBox(height: 16.h),
                    ],
                    SearchBarWidget(
                      hint: 'ابحث عن طالب بالاسم أو رقم الهاتف...',
                      controller: _searchController,
                      onChanged: (_) => setState(() => _applyFilter()),
                    ),
                    SizedBox(height: 12.h),
                    _FilterChipGroup(
                      filters: [
                        'الكل (${_students.length})',
                        'نشط ($activeCount)',
                        'غير نشط ($inactiveCount)',
                      ],
                      selectedIndex: _filterIndex,
                      onChanged: (i) => setState(() {
                        _filterIndex = i;
                        _applyFilter();
                      }),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _groups.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: 300.h,
                          alignment: Alignment.center,
                          child: Text(
                            'لا يوجد طلاب',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: _groups.length,
                        separatorBuilder: (_, _) => SizedBox(height: 20.h),
                        itemBuilder: (_, i) {
                          final group = _groups[i];
                          final canManage =
                              ref.watch(authProvider).user?.canManageAccounts ??
                              false;
                          final canDelete =
                              ref.watch(authProvider).user?.canDeleteAccounts ??
                              false;
                          return HalaqaGroupSection(
                            title: group.name,
                            count: group.students.length,
                            isUnassigned: group.isUnassigned,
                            isExpanded: _isExpanded(group),
                            onToggle: () => setState(() {
                              if (!_collapsed.remove(group.halaqaId)) {
                                _collapsed.add(group.halaqaId);
                              }
                            }),
                            children: [
                              for (final student in group.students)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: _StudentCard(
                                    student: student,
                                    canManage: canManage,
                                    canDelete: canDelete,
                                    onEdit: () => _openForm(student),
                                    onDelete: () =>
                                        _deleteStudent(student['id'] as int),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    this.canManage = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });
  final Map<String, dynamic> student;
  final bool canManage;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final user = student['user'] as Map<String, dynamic>? ?? {};
    final fullName = user['fullName'] ?? '';
    final phone = user['phone'] ?? '';
    final isActive = user['isActive'] ?? true;
    // The endpoint embeds a single `halaqa` object, not a join list.
    final halaqa = student['halaqa'] as Map<String, dynamic>?;
    final halaqaName = (halaqa?['name']?.toString().trim().isNotEmpty ?? false)
        ? halaqa!['name'].toString()
        : 'غير مسجل في حلقة';
    final count = student['_count'] as Map<String, dynamic>? ?? {};
    final attendanceCount = count['attendance'] ?? 0;

    return Container(
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
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon(Icons.visibility_outlined,
              //     color: AppColors.primary, size: 20.w),
              if (canManage) ...[
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(
                    Icons.edit_outlined,
                    color: AppColors.onSurfaceVariant,
                    size: 25.w,
                  ),
                ),
              ],
              SizedBox(height: 8.h),
              if (canDelete) ...[
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 25.w,
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    fullName,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.onPrimaryContainer,
                      size: 28.w,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              if (phone.isNotEmpty)
                Row(
                  children: [
                    Text(
                      phone,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                    child: Text(
                      '$attendanceCount حضور',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? AppColors.primary : AppColors.outline)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusFull,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          isActive ? 'نشط' : 'غير نشط',
                          style: AppTextStyles.labelSm.copyWith(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                halaqaName,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipGroup extends StatelessWidget {
  const _FilterChipGroup({
    required this.filters,
    required this.selectedIndex,
    required this.onChanged,
  });
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: filters.asMap().entries.map((e) {
          final isSelected = e.key == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: Container(
              margin: EdgeInsets.only(right: e.key == 0 ? 0 : 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryContainer
                      : AppColors.outlineVariant,
                ),
              ),
              child: Text(
                e.value,
                style: AppTextStyles.labelMd.copyWith(
                  color: isSelected
                      ? AppColors.onPrimaryContainer
                      : AppColors.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
