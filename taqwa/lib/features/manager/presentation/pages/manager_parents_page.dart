import 'package:flutter/material.dart';
import 'package:taqwa/core/utils/search_text.dart';
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
import '../../../../core/widgets/list_layout.dart';
import '../../../../core/widgets/last_seen_label.dart';
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

  static const _layoutKey = 'manager_parents';
  ListLayout _layout = ListLayout.list;

  void _setLayout(ListLayout layout) {
    setState(() => _layout = layout);
    ListLayoutStore.write(_layoutKey, layout);
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
    final q = _searchController.text;
    var list = _parents
        .where((p) => matchesSearch(q, [p.fullName, p.phone, ...p.extraPhones]))
        .toList();

    if (_filterIndex == 1) {
      list = list.where((p) => p.isActive == true).toList();
    } else if (_filterIndex == 2) {
      list = list.where((p) => p.isActive == false).toList();
    } else if (_filterIndex == 3) {
      list = list.where((p) => p.lastActiveAt == null).toList();
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
    final neverCount = _parents.where((p) => p.lastActiveAt == null).length;

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
                      Row(
                        children: [
                          ListLayoutToggle(
                            value: _layout,
                            onChanged: _setLayout,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: SearchBarWidget(
                              hint: 'ابحث عن ولي أمر بالاسم أو رقم الهاتف...',
                              controller: _searchController,
                              onChanged: (_) => setState(() => _applyFilter()),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      FilterChipGroup(
                        filters: [
                          'الكل (${_parents.length})',
                          'نشط ($activeCount)',
                          'غير نشط ($inactiveCount)',
                          'لم يدخل بعد ($neverCount)',
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
                                for (final parent
                                    in _filtered
                                        .skip(row * columns)
                                        .take(columns))
                                  _ParentGridCard(
                                    parent: parent,
                                    canManage: canManage,
                                    canDelete: canDelete,
                                    onOpenDetails: () => _openDetails(
                                      parent,
                                      canEdit: canManage,
                                    ),
                                    onEdit: () => _openForm(parent),
                                    onDelete: () => _deleteParent(parent.id!),
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
        // The Expanded has to be a direct child of this Row: a list item has
        // no bounded height, so a flex child inside the Column would throw.
        // It (not a Spacer) also bounds the details' width, which the
        // last-seen line needs to ellipsize.
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
            Expanded(
              child: Column(
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
                  SizedBox(height: 6.h),
                  LastSeenLabel(lastSeen: parent.lastActiveAt),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// The grid layout's card: the same facts as [_ParentCard], stacked to fit
/// half the screen's width. Edit and delete appear only for a manager allowed
/// them, as on the list card.
class _ParentGridCard extends StatelessWidget {
  const _ParentGridCard({
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
    final phone = parent.phone ?? '';

    return GestureDetector(
      onTap: onOpenDetails,
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
        ),
        padding: EdgeInsets.all(12.w),
        child: Column(
          children: [
            AvatarWidget(
              avatarUrl: parent.avatar,
              size: 48.w,
              backgroundColor: AppColors.tertiaryContainer,
              fallback: AppText(
                parent.fullName.isNotEmpty ? parent.fullName[0] : '؟',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onTertiaryContainer,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            AppText(
              parent.fullName,
              style: AppTextStyles.bodyMdBold.copyWith(
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (phone.isNotEmpty) ...[
              SizedBox(height: 4.h),
              AppText(
                phone,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 4.h),
            LastSeenLabel(lastSeen: parent.lastActiveAt, centered: true),
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
            if (canManage || canDelete) ...[
              const Spacer(),
              SizedBox(height: 10.h),
              Row(
                children: [
                  if (canDelete)
                    Expanded(
                      child: GridCardAction(
                        tooltip: 'حذف',
                        icon: Icons.delete_outline,
                        color: AppColors.error,
                        background: AppColors.errorContainer,
                        onTap: onDelete,
                      ),
                    ),
                  if (canDelete && canManage) SizedBox(width: 6.w),
                  if (canManage)
                    Expanded(
                      child: GridCardAction(
                        tooltip: 'تعديل',
                        icon: Icons.edit_outlined,
                        color: AppColors.secondary,
                        border: AppColors.outlineVariant,
                        onTap: onEdit,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
