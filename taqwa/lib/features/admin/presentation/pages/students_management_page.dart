import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import '../../../../features/data/models/student/student_model.dart';
import '../../../../features/data/repositories/student_repository.dart';
import '../../../shared/presentation/pages/student_details_page.dart';
import '../../../shared/presentation/pages/student_form_page.dart';
import '../admin_shell.dart';
import 'package:taqwa/core/utils/student_grouping.dart';
import 'package:taqwa/core/widgets/avatar_widget.dart';
import 'package:taqwa/core/widgets/card_action_row.dart';
import 'package:taqwa/core/widgets/confirm_status_dialog.dart';
import 'package:taqwa/core/widgets/halaqa_group_section.dart';
import 'package:taqwa/features/data/repositories/user_repository.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class StudentsManagementPage extends StatefulWidget {
  const StudentsManagementPage({super.key});

  @override
  State<StudentsManagementPage> createState() => _StudentsManagementPageState();
}

class _StudentsManagementPageState extends State<StudentsManagementPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<HalaqaGroup> _groups = [];
  List<String> _halaqaFilters = ['الكل'];
  int _filterIndex = 0;
  bool _isLoading = true;

  /// Halaqa ids the user folded away, kept across reloads and filter changes.
  /// Null stands for the unassigned bucket.
  final Set<int?> _collapsed = {};
  final _studentRepo = StudentRepository();
  final _userRepo = UserRepository();

  /// Opens the shared student form: [student] null creates, otherwise edits
  /// that row. The list holds raw API maps, so it is decoded here.
  Future<void> _openForm(Map<String, dynamic>? student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormPage(
          student: student == null ? null : StudentModel.fromJson(student),
          canSetHadithBooks: true,
        ),
      ),
    );
    if (mounted) _load();
  }

  /// Opens the shared read-only profile. The four values it needs are already
  /// in the list payload, so the page can draw its header before its own
  /// `GET /students/:id/profile` returns.
  void _openDetails(Map<String, dynamic> student) {
    final user = student['user'] as Map<String, dynamic>? ?? const {};
    final halaqa = student['halaqa'] as Map<String, dynamic>?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDetailsPage(
          studentId: student['id'] as int,
          fullName: (user['fullName'] as String?) ?? '',
          avatar: user['avatar'] as String?,
          halaqaId: (halaqa?['id'] as num?)?.toInt(),
          canEditParent: true,
        ),
      ),
    );
  }

  Future<void> _deleteStudent(int id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف الطالب',
      message: 'سيتم حذف حساب الطالب وجميع سجلاته نهائياً. '
          'لا يمكن التراجع عن هذا الإجراء.',
    );
    if (!confirmed) return;
    try {
      await _studentRepo.deleteStudent(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم حذف الطالب بنجاح')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(StudentRepository.errorMessage(e))),
      );
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> student) async {
    final user = student['user'] as Map<String, dynamic>?;
    final userId = (user?['id'] as num?)?.toInt();
    if (userId == null) return;
    final isActive = (user?['isActive'] as bool?) ?? true;
    final newStatus = !isActive;
    final confirmed = await ConfirmStatusDialog.show(
      context,
      isCurrentlyActive: isActive,
      userName:
          (user?['fullName'] as String?) ??
          (student['fullName'] as String?) ??
          'هذا الحساب',
    );
    if (!confirmed) return;
    try {
      await _userRepo.setActive(userId, newStatus);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(StudentRepository.errorMessage(e))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dio = DioClient.instance;
      final res = await dio.get(ApiEndpoints.students);
      final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
      final halaqaNames = <String>{};
      for (final s in list) {
        final halaqa = s['halaqa'] as Map<String, dynamic>?;
        final name = halaqa?['name'] as String?;
        if (name != null) halaqaNames.add(name);
      }
      if (mounted) {
        setState(() {
          _students = list;
          _halaqaFilters = ['الكل', ...halaqaNames];
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
      return q.isEmpty || name.contains(q);
    }).toList();
    if (_filterIndex > 0 && _filterIndex < _halaqaFilters.length) {
      final target = _halaqaFilters[_filterIndex];
      list = list.where((s) {
        final halaqa = s['halaqa'] as Map<String, dynamic>?;
        return halaqa?['name'] == target;
      }).toList();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => AdminShellScope.of(context)?.openMenu(),
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppColors.onPrimaryContainer,
                            size: 18.w,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        AppText(
                          'تقوى',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    AppText(
                      'قائمة الطلاب',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    AppText(
                      'إدارة متابعة حفظ الطلاب وحضورهم.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SearchBarWidget(
                      hint: 'ابحث باسم الطالب...',
                      controller: _searchController,
                      onChanged: (_) => setState(() => _applyFilter()),
                    ),
                    SizedBox(height: 12.h),
                    FilterChipGroup(
                      filters: _halaqaFilters,
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
                        child: CircularProgressIndicator(color: AppColors.primary))
                    : _groups.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: 300.h,
                              alignment: Alignment.center,
                              child: AppText(
                                'لا يوجد طلاب',
                                style: AppTextStyles.bodyMd
                                    .copyWith(color: AppColors.onSurfaceVariant),
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
                                      padding: EdgeInsets.only(bottom: 16.h),
                                      child: _StudentCard(
                                        student: student,
                                        onOpenDetails: () =>
                                            _openDetails(student),
                                        onEdit: () => _openForm(student),
                                        onDelete: () => _deleteStudent(
                                          student['id'] as int,
                                        ),
                                        onToggleActive: () =>
                                            _toggleStatus(student),
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_student',
        onPressed: () => _openForm(null),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: AppColors.onPrimary),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });
  final Map<String, dynamic> student;
  /// Tapping the card body opens the profile. Edit, delete and the status
  /// toggle stay on their own buttons inside it, and their own gesture
  /// detectors win over this one, so the row keeps all four actions.
  final VoidCallback onOpenDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final user = student['user'] as Map<String, dynamic>? ?? {};
    final fullName = user['fullName'] ?? '';
    final isActive = user['isActive'] ?? true;
    final halaqa = student['halaqa'] as Map<String, dynamic>?;
    final halaqaName = halaqa?['name'] ?? 'غير مسجل';
    final counts = student['_count'] as Map<String, dynamic>? ?? {};
    final attendanceCount = counts['attendance'] ?? 0;
    final memCount = counts['memorization'] ?? 0;

    return GestureDetector(
      onTap: onOpenDetails,
      // Opaque so the padding around the content is part of the target, not
      // just the text and the avatar.
      behavior: HitTestBehavior.opaque,
      child: Container(
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
          border: Border(
            right: BorderSide(color: AppColors.primary, width: 4.w),
          ),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: AppText(
                    isActive ? 'نشط' : 'غير نشط',
                    style: AppTextStyles.labelSm.copyWith(
                      color: isActive ? AppColors.primary : AppColors.outline,
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      fullName,
                      style: AppTextStyles.bodyMdBold.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                      ),
                      child: AppText(
                        halaqaName,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12.w),
                AvatarWidget(
                  avatarUrl:
                      (student['avatar'] as String?) ??
                      (user['avatar'] as String?),
                  size: 44.w,
                  fallback: AppText(
                    fullName.isNotEmpty ? fullName[0] : '؟',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _InfoCell(label: 'حضور', value: '$attendanceCount'),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _InfoCell(label: 'حفظ', value: '$memCount'),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            CardActionRow(
              isActive: isActive,
              onToggleActive: onToggleActive,
              onDelete: onDelete,
              onEdit: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(label,
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)),
          SizedBox(height: 2.h),
          AppText(value,
              style: AppTextStyles.labelMdBold
                  .copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }
}

