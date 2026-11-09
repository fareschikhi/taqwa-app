import 'package:flutter/material.dart';
import 'package:taqwa/core/utils/search_text.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/telegram.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/repositories/teacher_repository.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';
import 'package:taqwa/core/widgets/avatar_widget.dart';
import 'package:taqwa/core/widgets/card_action_row.dart';
import 'package:taqwa/core/widgets/confirm_status_dialog.dart';
import 'package:taqwa/core/widgets/list_layout.dart';
import 'package:taqwa/features/data/repositories/user_repository.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';
import 'package:taqwa/core/widgets/points_section.dart';
import 'create_teacher_page.dart';
import '../admin_shell.dart';
import 'package:taqwa/core/widgets/app_text.dart';

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
  final _pointsRepo = PointsRepository();

  static const _layoutKey = 'admin_teachers';
  ListLayout _layout = ListLayout.list;

  void _setLayout(ListLayout layout) {
    setState(() => _layout = layout);
    ListLayoutStore.write(_layoutKey, layout);
  }

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

  /// A teacher's points, which only the admin gives or takes. Teachers have no
  /// details page, so they open in a sheet from the card. Loaded by the
  /// teacher's account id ([TeacherModel.userId]), not the teacher-row id.
  void _showPoints(TeacherModel teacher) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                teacher.fullName,
                style: AppTextStyles.labelMdBold,
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 12.h),
              PointsSection(
                load: () => _pointsRepo.forUser(teacher.userId),
                canAdjust: true,
                hideWhenUnavailable: false,
              ),
            ],
          ),
        ),
      ),
    );
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
          SnackBar(content: AppText(TeacherRepository.errorMessage(e))),
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
      ).showSnackBar(const SnackBar(content: AppText('تم حذف المعلم بنجاح')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(TeacherRepository.errorMessage(e))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    ListLayoutStore.read(_layoutKey).then((layout) {
      if (mounted && layout != _layout) setState(() => _layout = layout);
    });
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
    final q = _searchController.text;
    var list = _teachers
        .where((t) => matchesSearch(q, [t.fullName, t.phone, ...t.extraPhones]))
        .toList();

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
                    SizedBox(width: 12.w),
                    Expanded(
                      child: AppText(
                        'إدارة المعلمين',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.headlineLgMobile.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
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
                    Row(
                      children: [
                        ListLayoutToggle(value: _layout, onChanged: _setLayout),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: SearchBarWidget(
                            hint: 'ابحث عن معلم بالاسم أو رقم الهاتف...',
                            controller: _searchController,
                            onChanged: (_) => setState(() => _applyFilter()),
                          ),
                        ),
                      ],
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
                          child: AppText(
                            'لا يوجد معلمون',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : _layout == ListLayout.grid
                    ? LayoutBuilder(
                        builder: (_, constraints) {
                          final columns = cardGridColumns(
                            constraints.maxWidth - 32.w,
                          );
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                            itemCount: (_filtered.length / columns).ceil(),
                            separatorBuilder: (_, _) => SizedBox(height: 12.h),
                            itemBuilder: (_, row) => CardGridRow(
                              columns: columns,
                              children: [
                                for (final teacher
                                    in _filtered
                                        .skip(row * columns)
                                        .take(columns))
                                  _TeacherGridCard(
                                    teacher: teacher,
                                    onEdit: () => _openForm(teacher),
                                    onDelete: () => _deleteTeacher(
                                      teacher.id,
                                      teacher.halaqaCount,
                                    ),
                                    onToggleActive: () =>
                                        _toggleStatus(teacher),
                                    onPoints: () => _showPoints(teacher),
                                  ),
                              ],
                            ),
                          );
                        },
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
                          onPoints: () => _showPoints(_filtered[i]),
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
    required this.onPoints,
  });
  final TeacherModel teacher;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onPoints;

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
                    AppText(
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
                fallback: AppText(
                  name.isNotEmpty ? name[0] : '؟',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          AppText(
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
              AppText(
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
                      AppText(
                        '$halaqaCount',
                        style: AppTextStyles.headlineMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      AppText(
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
                      AppText(
                        '$studentCount',
                        style: AppTextStyles.headlineMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      AppText(
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
            onPoints: onPoints,
            onDelete: onDelete,
            onEdit: onEdit,
            // Teachers have no details page, so the card is where the admin
            // reaches them on Telegram.
            onTelegram: telegramUri(phone) != null
                ? () => openTelegram(context, phone)
                : null,
          ),
        ],
      ),
    );
  }
}

/// The grid layout's card: the same facts and actions as [_TeacherCard],
/// stacked to fit half the screen's width.
class _TeacherGridCard extends StatelessWidget {
  const _TeacherGridCard({
    required this.teacher,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onPoints,
  });
  final TeacherModel teacher;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onPoints;

  @override
  Widget build(BuildContext context) {
    final name = teacher.fullName;
    final phone = teacher.phone ?? '';
    final isActive = teacher.isActive;

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
      padding: EdgeInsets.all(12.w),
      child: Column(
        children: [
          AvatarWidget(
            avatarUrl: teacher.avatar,
            size: AppConstants.avatarLg,
            fallback: AppText(
              name.isNotEmpty ? name[0] : '؟',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          AppText(
            name,
            style: AppTextStyles.bodyMdBold.copyWith(
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4.h),
          AppText(
            phone.isNotEmpty ? phone : '—',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
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
                AppText(
                  isActive ? 'نشط' : 'في إجازة',
                  style: AppTextStyles.labelSm.copyWith(
                    color: isActive ? AppColors.primary : AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _GridStat(value: teacher.halaqaCount, label: 'حلقات'),
                ),
                Container(
                  width: 1,
                  height: 32.h,
                  color: AppColors.outlineVariant,
                ),
                Expanded(
                  child: _GridStat(value: teacher.studentCount, label: 'طلاب'),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          CardActionRow(
            compact: true,
            isActive: isActive,
            onToggleActive: onToggleActive,
            onPoints: onPoints,
            onDelete: onDelete,
            onEdit: onEdit,
            onTelegram: telegramUri(phone) != null
                ? () => openTelegram(context, phone)
                : null,
          ),
        ],
      ),
    );
  }
}

class _GridStat extends StatelessWidget {
  const _GridStat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppText(
          '$value',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        AppText(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
