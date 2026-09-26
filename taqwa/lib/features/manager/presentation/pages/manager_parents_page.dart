import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../features/data/models/parent/parent_model.dart';
import '../../../../features/data/repositories/parent_repository.dart';
import '../../../shared/presentation/pages/parent_details_page.dart';
import '../../../shared/presentation/pages/parent_form_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class ManagerParentsPage extends ConsumerStatefulWidget {
  const ManagerParentsPage({super.key});

  @override
  ConsumerState<ManagerParentsPage> createState() => _ManagerParentsPageState();
}

class _ManagerParentsPageState extends ConsumerState<ManagerParentsPage> {
  final _repo = ParentRepository();
  List<ParentModel> _parents = [];
  List<ParentModel> _filtered = [];
  bool _isLoading = true;
  int _filterIndex = 0;
  final _searchController = TextEditingController();

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
    // GET /parents itself requires MANAGE_ACCOUNTS; skip the call rather than
    // fire a request that is guaranteed to 403.
    if (!(ref.read(authProvider).user?.canManageAccounts ?? false)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
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

  Future<void> _openDetails(ParentModel parent, {required bool canEdit}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ParentDetailsPage(parent: parent, canEdit: canEdit),
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

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(authProvider).user?.canManageAccounts ?? false;
    final canDelete = ref.watch(authProvider).user?.canDeleteAccounts ?? false;
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
                child: Row(
                  children: [
                    const Spacer(),
                    AppText(
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
                    AppText(
                      'أولياء الأمور',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    AppText(
                      'إدارة أولياء أمور طلاب حلقاتك',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (canManage) ...[
                      SizedBox(height: 16.h),
                      AppButton(
                        label: 'إضافة ولي أمر',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.person_add,
                        onPressed: () => _openForm(null),
                      ),
                      SizedBox(height: 16.h),
                      SearchBarWidget(
                        hint: 'ابحث عن ولي أمر بالاسم أو رقم الهاتف...',
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
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: !canManage
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.w),
                          child: AppText(
                            'ليس لديك صلاحية لعرض أولياء الأمور',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _isLoading
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
                        separatorBuilder: (_, _) => SizedBox(height: 12.h),
                        itemBuilder: (_, i) => _ParentCard(
                          parent: _filtered[i],
                          canManage: canManage,
                          canDelete: canDelete,
                          onOpenDetails: () =>
                              _openDetails(_filtered[i], canEdit: canManage),
                          onEdit: () => _openForm(_filtered[i]),
                          onDelete: () => _deleteParent(_filtered[i].id!),
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
    required this.canManage,
    required this.canDelete,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onDelete,
  });

  final ParentModel parent;
  final bool canManage;
  final bool canDelete;
  final VoidCallback onOpenDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = parent.isActive ?? true;

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
        padding: EdgeInsets.all(16.w),
        // The Spacer has to be a direct child of this Row: a list item has no
        // bounded height, so a flex child inside the Column would throw.
        child: Row(
          children: [
            // Actions, pinned to the left edge like the students card.
            if (canManage || canDelete)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canDelete)
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 25.w,
                      ),
                    ),
                  if (canDelete && canManage) SizedBox(height: 12.h),
                  if (canManage)
                    GestureDetector(
                      onTap: onEdit,
                      child: Icon(
                        Icons.edit_outlined,
                        color: AppColors.onSurfaceVariant,
                        size: 25.w,
                      ),
                    ),
                ],
              ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          parent.fullName,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        if ((parent.phone ?? '').isNotEmpty)
                          AppText(
                            parent.phone!,
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 12.w),
                    AvatarWidget(
                      avatarUrl: parent.avatar,
                      size: 44.w,
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
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: (isActive ? AppColors.primary : AppColors.outline)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: AppText(
                    isActive ? 'نشط' : 'غير نشط',
                    style: AppTextStyles.labelSm.copyWith(
                      color: isActive ? AppColors.primary : AppColors.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
