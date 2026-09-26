import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/core/widgets/card_action_row.dart';
import 'package:taqwa/core/widgets/confirm_status_dialog.dart';
import '../../../../features/data/models/parent/parent_model.dart';
import '../../../../features/data/repositories/parent_repository.dart';
import 'package:taqwa/features/data/repositories/user_repository.dart';
import '../../../shared/presentation/pages/parent_details_page.dart';
import '../../../shared/presentation/pages/parent_form_page.dart';
import '../admin_shell.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class ParentsManagementPage extends StatefulWidget {
  const ParentsManagementPage({super.key});

  @override
  State<ParentsManagementPage> createState() => _ParentsManagementPageState();
}

class _ParentsManagementPageState extends State<ParentsManagementPage> {
  final _repo = ParentRepository();
  final _userRepo = UserRepository();
  final _searchController = TextEditingController();
  List<ParentModel> _parents = [];
  List<ParentModel> _filtered = [];
  bool _isLoading = true;
  int _filterIndex = 0;

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
      final list = await _repo.getAllParents();
      if (mounted) {
        setState(() {
          _parents = list;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(ParentRepository.errorMessage(e))),
        );
      }
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    var list = _parents.where((p) {
      final name = p.fullName.toLowerCase();
      final phone = (p.phone ?? '').toLowerCase();
      return q.isEmpty || name.contains(q) || phone.contains(q);
    }).toList();

    if (_filterIndex == 1) {
      list = list.where((p) => p.isActive == true).toList();
    } else if (_filterIndex == 2) {
      list = list.where((p) => p.isActive == false).toList();
    }
    _filtered = list;
  }

  /// Opens the shared parent form: [parent] null creates, otherwise edits.
  Future<void> _openForm(ParentModel? parent) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParentFormPage(parent: parent)),
    );
    if (mounted) _load();
  }

  Future<void> _openDetails(ParentModel parent) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ParentDetailsPage(parent: parent, canEdit: true),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _deleteParent(int id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف ولي الأمر',
      message:
          'سيتم حذف حساب ولي الأمر نهائياً. '
          'سيبقى الأبناء في النظام دون ولي أمر مرتبط.',
    );
    if (!confirmed) return;
    try {
      await _repo.deleteParent(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم حذف ولي الأمر بنجاح')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(ParentRepository.errorMessage(e))),
      );
    }
  }

  Future<void> _toggleStatus(ParentModel parent) async {
    final userId = parent.userId;
    if (userId == null) return;
    final isActive = parent.isActive ?? true;
    final newStatus = !isActive;
    final confirmed = await ConfirmStatusDialog.show(
      context,
      isCurrentlyActive: isActive,
      userName: parent.fullName,
    );
    if (!confirmed) return;
    try {
      await _userRepo.setActive(userId, newStatus);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(ParentRepository.errorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _parents.where((p) => p.isActive == true).length;
    final inactiveCount = _parents.length - activeCount;

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
                      'أولياء الأمور',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    AppText(
                      'متابعة التواصل مع أولياء أمور الطلاب.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    AppButton(
                      label: 'إضافة ولي أمر جديد',
                      variant: AppButtonVariant.gradient,
                      icon: Icons.person_add,
                      onPressed: () => _openForm(null),
                    ),
                    SizedBox(height: 16.h),
                    SearchBarWidget(
                      hint: 'ابحث عن ولي أمر...',
                      controller: _searchController,
                      onChanged: (_) => setState(() => _applyFilter()),
                    ),
                    SizedBox(height: 12.h),
                    FilterChipGroup(
                      filters: [
                        'الكل (${_parents.length})',
                        'نشط ($activeCount)',
                        'غير نشط ($inactiveCount)',
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
                            'لا يوجد أولياء أمور',
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
                        itemBuilder: (_, i) => _ParentCard(
                          parent: _filtered[i],
                          isActive: _filtered[i].isActive ?? true,
                          onOpenDetails: () => _openDetails(_filtered[i]),
                          onEdit: () => _openForm(_filtered[i]),
                          onDelete: () => _deleteParent(_filtered[i].id!),
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

class _ParentCard extends StatelessWidget {
  const _ParentCard({
    required this.parent,
    required this.isActive,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final ParentModel parent;
  final bool isActive;
  final VoidCallback onOpenDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenDetails,
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
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isActive
                                          ? AppColors.primary
                                          : AppColors.outline)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusFull,
                              ),
                            ),
                            child: AppText(
                              isActive ? 'نشط' : 'غير نشط',
                              style: AppTextStyles.labelSm.copyWith(
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      AppText(
                        parent.fullName,
                        style: AppTextStyles.bodyMdBold.copyWith(
                          color: AppColors.onSurface,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      if ((parent.phone ?? '').isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AppText(
                              parent.phone!,
                              style: AppTextStyles.labelSm.copyWith(
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
                      ],
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppText(
                            '${parent.children.length} طالب مرتبط',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          const Icon(
                            Icons.group,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                AvatarWidget(
                  avatarUrl: parent.avatar,
                  size: 52.w,
                  backgroundColor: AppColors.tertiaryContainer,
                  fallback: AppText(
                    parent.fullName.isNotEmpty ? parent.fullName[0] : '؟',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onTertiaryContainer,
                    ),
                  ),
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
