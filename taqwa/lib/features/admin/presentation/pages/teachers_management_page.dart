import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/repositories/teacher_repository.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';
import 'package:taqwa/core/widgets/avatar_widget.dart';
import 'package:taqwa/core/widgets/card_action_row.dart';
import 'package:taqwa/core/widgets/confirm_status_dialog.dart';
import 'package:taqwa/features/data/repositories/user_repository.dart';
import 'create_teacher_page.dart';
import '../admin_shell.dart';

class TeachersManagementPage extends StatefulWidget {
  const TeachersManagementPage({super.key});

  @override
  State<TeachersManagementPage> createState() => _TeachersManagementPageState();
}

class _TeachersManagementPageState extends State<TeachersManagementPage> {
  int _filterIndex = 0;
  final _searchController = TextEditingController();
  List<TeacherModel> _teachers = [];
  List<TeacherModel> _filtered = [];
  bool _isLoading = true;
  final _teacherRepo = TeacherRepository();
  final _userRepo = UserRepository();

  /// Opens the create/edit form: [teacher] null creates, otherwise edits.
  Future<void> _openForm(TeacherModel? teacher) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTeacherPage(editTeacher: teacher),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _toggleStatus(TeacherModel teacher) async {
    final newStatus = !teacher.isActive;
    final confirmed = await ConfirmStatusDialog.show(
      context,
      isCurrentlyActive: teacher.isActive,
      userName: teacher.user.fullName,
    );
    if (!confirmed) return;
    try {
      await _userRepo.setActive(teacher.userId, newStatus);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TeacherRepository.errorMessage(e))),
        );
      }
    }
  }

  Future<void> _deleteTeacher(int id, int halaqaCount) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف المعلم',
      message: halaqaCount > 0
          ? 'سيتم حذف حساب المعلم نهائياً، وسيتم أيضاً حذف '
                '$halaqaCount من الحلقات المسندة إليه. '
                'سيبقى الطلاب في النظام دون حلقة.'
          : 'سيتم حذف حساب المعلم نهائياً. '
                'لا يمكن التراجع عن هذا الإجراء.',
    );
    if (!confirmed) return;
    try {
      await _teacherRepo.deleteTeacher(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المعلم بنجاح')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TeacherRepository.errorMessage(e))),
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
      final list = await _teacherRepo.getAllTeachers();
      if (mounted) {
        setState(() {
          _teachers = list;
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
    var list = _teachers.where((t) {
      final name = t.fullName.toLowerCase();
      final phone = t.phone ?? '';
      return q.isEmpty || name.contains(q) || phone.contains(q);
    }).toList();

    if (_filterIndex == 1) {
      list = list.where((t) => t.isActive == true).toList();
    } else if (_filterIndex == 2) {
      list = list.where((t) => t.isActive != true).toList();
    }
    _filtered = list;
  }

  int get _activeCount => _teachers.where((t) => t.isActive == true).length;

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
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => AdminShellScope.of(context)?.openMenu(),
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: AppColors.onPrimaryContainer,
                        size: 22.w,
                      ),
                    ),
                    SizedBox(width: 8.w),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'إدارة المعلمين',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'إدارة وتوجيه المدرسة القرآنية',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    AppButton(
                      label: 'إضافة معلم جديد',
                      variant: AppButtonVariant.gradient,
                      icon: Icons.person_add,
                      onPressed: () => _openForm(null),
                    ),
                    SizedBox(height: 16.h),
                    SearchBarWidget(
                      hint: 'ابحث عن معلم بالاسم أو رقم الهاتف...',
                      controller: _searchController,
                      onChanged: (_) => setState(() => _applyFilter()),
                    ),
                    SizedBox(height: 12.h),
                    FilterChipGroup(
                      filters: [
                        'الكل (${_teachers.length})',
                        'نشط ($_activeCount)',
                        'في إجازة (${_teachers.length - _activeCount})',
                      ],
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
                    : _filtered.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: 300.h,
                          alignment: Alignment.center,
                          child: Text(
                            'لا يوجد معلمون',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => SizedBox(height: 16.h),
                        itemBuilder: (_, i) => _TeacherCard(
                          teacher: _filtered[i],
                          isActive: _filtered[i].isActive,
                          onEdit: () => _openForm(_filtered[i]),
                          onDelete: () => _deleteTeacher(
                            _filtered[i].id,
                            // findAll returns only _count.halaqas; the
                            // halaqas relation itself is stripped server-side.
                            _filtered[i].halaqaCount,
                          ),
                          onToggleActive: () => _toggleStatus(_filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({
    required this.teacher,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });
  final TeacherModel teacher;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final name = teacher.fullName;
    final phone = teacher.phone ?? '';
    final studentCount = teacher.studentCount;
    // The halaqas relation is stripped by findAll; only _count survives.
    final halaqaCount = teacher.halaqaCount;

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
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.primary : AppColors.outline)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      isActive ? 'نشط' : 'في إجازة',
                      style: AppTextStyles.labelSm.copyWith(
                        color: isActive ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AvatarWidget(
                avatarUrl: teacher.avatar,
                size: AppConstants.avatarXl,
                fallback: Text(
                  name.isNotEmpty ? name[0] : '؟',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            name,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                phone.isNotEmpty ? phone : '—',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 4.w),
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$halaqaCount',
                        style: AppTextStyles.headlineMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'حلقات مكلف بها',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40.h,
                  color: AppColors.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$studentCount',
                        style: AppTextStyles.headlineMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'إجمالي الطلاب',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          CardActionRow(
            isActive: isActive,
            onToggleActive: onToggleActive,
            onDelete: onDelete,
            onEdit: onEdit,
          ),
        ],
      ),
    );
  }
}
