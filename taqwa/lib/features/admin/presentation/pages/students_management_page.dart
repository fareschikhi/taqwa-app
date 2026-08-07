import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../features/data/models/student/student_model.dart';
import '../../../../features/data/repositories/student_repository.dart';
import '../../../shared/presentation/pages/student_form_page.dart';
import '../admin_shell.dart';

class StudentsManagementPage extends StatefulWidget {
  const StudentsManagementPage({super.key});

  @override
  State<StudentsManagementPage> createState() => _StudentsManagementPageState();
}

class _StudentsManagementPageState extends State<StudentsManagementPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _halaqaFilters = ['الكل'];
  int _filterIndex = 0;
  bool _isLoading = true;
  final _studentRepo = StudentRepository();

  /// Opens the shared student form: [student] null creates, otherwise edits
  /// that row. The list holds raw API maps, so it is decoded here.
  Future<void> _openForm(Map<String, dynamic>? student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormPage(
          student: student == null ? null : StudentModel.fromJson(student),
        ),
      ),
    );
    if (mounted) _load();
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
        const SnackBar(content: Text('تم حذف الطالب بنجاح')),
      );
      _load();
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
    _filtered = list;
  }

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
                        Text(
                          'تقوى',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'قائمة الطلاب',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
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
                    : _filtered.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: 300.h,
                              alignment: Alignment.center,
                              child: Text(
                                'لا يوجد طلاب',
                                style: AppTextStyles.bodyMd
                                    .copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) => SizedBox(height: 16.h),
                            itemBuilder: (_, i) => _StudentCard(
                              student: _filtered[i],
                              onEdit: () => _openForm(_filtered[i]),
                              onDelete: () => _deleteStudent(
                                _filtered[i]['id'] as int,
                              ),
                            ),
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
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                child: Text(
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
                  Text(
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
                    child: Text(
                      halaqaName,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.onPrimaryContainer,
                  size: 26.w,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: onEdit,
                child: Icon(
                  Icons.edit_outlined,
                  color: AppColors.onSurfaceVariant,
                  size: 20.w,
                ),
              ),
            ],
          ),
        ],
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
          Text(label,
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)),
          SizedBox(height: 2.h),
          Text(value,
              style: AppTextStyles.labelMdBold
                  .copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }
}

