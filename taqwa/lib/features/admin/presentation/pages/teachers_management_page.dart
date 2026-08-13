import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import '../../../../features/data/repositories/teacher_repository.dart';
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
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _teacherRepo = TeacherRepository();

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المعلم بنجاح')),
      );
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
      final dio = DioClient.instance;
      final res = await dio.get(ApiEndpoints.teachers);
      final list = (res.data as List).cast<Map<String, dynamic>>();
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
      final user = t['user'] as Map<String, dynamic>? ?? {};
      final name = (user['fullName'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString();
      return q.isEmpty || name.contains(q) || phone.contains(q);
    }).toList();

    if (_filterIndex == 1) {
      list = list.where((t) {
        final user = t['user'] as Map<String, dynamic>? ?? {};
        return user['isActive'] == true;
      }).toList();
    } else if (_filterIndex == 2) {
      list = list.where((t) {
        final user = t['user'] as Map<String, dynamic>? ?? {};
        return user['isActive'] != true;
      }).toList();
    }
    _filtered = list;
  }

  int get _activeCount =>
      _teachers.where((t) => (t['user']?['isActive'] ?? false) == true).length;

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
                      'إدارة وتوجيه الكادر التعليمي في المعهد',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    AppButton(
                      label: 'إضافة معلم جديد',
                      variant: AppButtonVariant.gradient,
                      icon: Icons.person_add,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateTeacherPage(),
                        ),
                      ).then((_) => _load()),
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
                        child:
                            CircularProgressIndicator(color: AppColors.primary))
                    : _filtered.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: 300.h,
                              alignment: Alignment.center,
                              child: Text(
                                'لا يوجد معلمون',
                                style: AppTextStyles.bodyMd
                                    .copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: 16.h),
                            itemBuilder: (_, i) => _TeacherCard(
                              teacher: _filtered[i],
                              onDelete: () => _deleteTeacher(
                                _filtered[i]['id'] as int,
                                // findAll returns only _count.halaqas; the
                                // halaqas relation itself is stripped server-side.
                                (_filtered[i]['_count']
                                        as Map<String, dynamic>?)?['halaqas']
                                        as int? ??
                                    0,
                              ),
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
  const _TeacherCard({required this.teacher, required this.onDelete});
  final Map<String, dynamic> teacher;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final user = teacher['user'] as Map<String, dynamic>? ?? {};
    final name = user['fullName'] ?? '';
    final phone = user['phone'] ?? '';
    final isActive = user['isActive'] ?? true;
    final counts = teacher['_count'] as Map<String, dynamic>? ?? {};
    final studentCount = counts['students'] ?? 0;
    // The halaqas relation is stripped by findAll; only _count survives.
    final halaqaCount = counts['halaqas'] ?? 0;

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
                  color:
                      (isActive ? AppColors.primary : AppColors.outline)
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
                        color: isActive
                            ? AppColors.primary
                            : AppColors.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                     Text(
                       isActive ? 'نشط' : 'في إجازة',
                       style: AppTextStyles.labelSm.copyWith(
                         color: isActive
                             ? AppColors.primary
                             : AppColors.outline,
                       ),
                     ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: AppConstants.avatarXl,
                height: AppConstants.avatarXl,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryContainer,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.onPrimaryContainer,
                  size: 36.w,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionBtn(
                icon: Icons.delete_outline,
                color: AppColors.error,
                onTap: onDelete,
              ),
              _ActionBtn(
                icon: Icons.assignment_add,
                color: AppColors.secondary,
                onTap: () {},
              ),
              _ActionBtn(
                icon: Icons.edit_outlined,
                color: AppColors.onSurfaceVariant,
                onTap: () {},
              ),
              _ActionBtn(
                icon: Icons.visibility_outlined,
                color: AppColors.primary,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: color, size: 24.w),
  );
}
