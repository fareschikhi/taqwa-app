import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/core/widgets/avatar_widget.dart';
import 'package:taqwa/core/widgets/card_action_row.dart';
import 'package:taqwa/core/widgets/confirm_status_dialog.dart';
import '../../../../features/data/repositories/manager_repository.dart';
import '../../../../features/data/models/manager_model.dart';
import 'create_manager_page.dart';
import 'manager_details_page.dart';
import '../admin_shell.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class ManagersManagementPage extends StatefulWidget {
  const ManagersManagementPage({super.key});

  @override
  State<ManagersManagementPage> createState() => _ManagersManagementPageState();
}

class _ManagersManagementPageState extends State<ManagersManagementPage> {
  final _repo = ManagerRepository();
  final _searchController = TextEditingController();
  List<ManagerModel> _managers = [];
  List<ManagerModel> _filtered = [];
  bool _isLoading = true;
  int _filterIndex = 0; // 0=all, 1=active, 2=inactive

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
      final list = await _repo.getAllManagers();
      if (mounted) {
        setState(() {
          _managers = list;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(ManagerRepository.errorMessage(e))),
        );
      }
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    var list = _managers.where((m) {
      final name = m.fullName.toLowerCase();
      final phone = (m.phone ?? '').toLowerCase();
      return q.isEmpty || name.contains(q) || phone.contains(q);
    }).toList();

    if (_filterIndex == 1) {
      list = list.where((m) => m.isActive == true).toList();
    } else if (_filterIndex == 2) {
      list = list.where((m) => m.isActive != true).toList();
    }
    _filtered = list;
  }

  Future<void> _deleteManager(ManagerModel m) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف المدير',
      message:
          'سيتم حذف حساب المدير نهائياً مع تعييناته للحلقات '
          'وتبريرات الغياب التي سجّلها. لتعطيل الحساب مؤقتاً '
          'استخدم زر إيقاف التنشيط بدلاً من الحذف.',
    );
    if (!confirmed) return;
    try {
      await _repo.deleteManager(m.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('تم حذف المدير بنجاح')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(ManagerRepository.errorMessage(e))),
      );
    }
  }

  Future<void> _openDetails(ManagerModel m) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ManagerDetailsPage(manager: m)),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _toggleStatus(ManagerModel m) async {
    final isActive = m.isActive ?? true;
    final newStatus = !isActive;
    final confirmed = await ConfirmStatusDialog.show(
      context,
      isCurrentlyActive: isActive,
      userName: m.fullName,
    );
    if (!confirmed) return;
    try {
      await _repo.updateManagerStatus(m.id!, newStatus);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(ManagerRepository.errorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _managers.where((m) => m.isActive == true).length;
    final inactiveCount = _managers.length - activeCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildHeader(context),
              SizedBox(height: 16.h),
              // Search + Filter Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Container(
                  padding: EdgeInsets.all(14.w),
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
                    children: [
                      SearchBarWidget(
                        hint: 'ابحث عن مدير...',
                        controller: _searchController,
                        onChanged: (_) => setState(() => _applyFilter()),
                      ),
                      SizedBox(height: 12.h),
                      _FilterChips(
                        filters: [
                          'الكل (${_managers.length})',
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
              ),
              SizedBox(height: 16.h),
              // Grid
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
                          child: _buildEmpty(),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => SizedBox(height: 12.h),
                        itemBuilder: (_, i) => _ManagerCard(
                          manager: _filtered[i],
                          onOpenDetails: () => _openDetails(_filtered[i]),
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreateManagerPage(editManager: _filtered[i]),
                            ),
                          ).then((_) => _load()),
                          onToggleStatus: () => _toggleStatus(_filtered[i]),
                          onDelete: () => _deleteManager(_filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateManagerPage()),
        ).then((_) => _load()),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.onPrimary),
        label: AppText(
          'إضافة مدير',
          style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
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
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
          SizedBox(height: 4.h),
          AppText(
            'الإدارة',
            style: AppTextStyles.headlineLgMobile.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          AppText(
            'تنظيم ومتابعة المديرين.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.manage_accounts_outlined,
              size: 40.w,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          AppText(
            'لا يوجد مديرون',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 8.h),
          AppText(
            'اضغط "إضافة مدير" لإضافة أول مدير',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Manager Card — matches admin_managers.html design
// ──────────────────────────────────────────────────────────────────────────────
class _ManagerCard extends StatelessWidget {
  const _ManagerCard({
    required this.manager,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });
  final ManagerModel manager;
  final VoidCallback onOpenDetails;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = manager.isActive ?? true;
    final halaqaName = manager.firstHalaqaName;
    final halaqasCount = manager.halaqasCount;

    return GestureDetector(
      onTap: onOpenDetails,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          border: Border.all(color: AppColors.surfaceVariant),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(18, 52, 59, 0.04),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Header row: avatar + name + status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: AppText(
                    isActive ? 'نشط' : 'غير نشط',
                    style: AppTextStyles.labelSm.copyWith(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                // Avatar + name/phone
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          manager.fullName,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (manager.phone != null)
                          Row(
                            children: [
                              AppText(
                                manager.phone!,
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              const Icon(
                                Icons.call,
                                size: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ],
                          ),
                      ],
                    ),
                    SizedBox(width: 12.w),
                    // Avatar circle. Keeps the inactive-dimmed background the
                    // card already used, so a deactivated manager still reads as
                    // deactivated even when they have a photo.
                    AvatarWidget(
                      avatarUrl: manager.avatar,
                      size: 52.w,
                      backgroundColor: isActive
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainerHigh,
                      fallback: AppText(
                        manager.fullName.isNotEmpty ? manager.fullName[0] : '؟',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: isActive
                              ? AppColors.onPrimaryContainer
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Info section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        halaqaName,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppText(
                        'الحلقة المعينة',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (halaqasCount > 1) ...[
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMd,
                            ),
                          ),
                          child: AppText(
                            '$halaqasCount حلقات',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        AppText(
                          'إجمالي الحلقات',
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12.h),
            CardActionRow(
              isActive: isActive,
              onToggleActive: onToggleStatus,
              onDelete: onDelete,
              onEdit: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Filter Chips
// ──────────────────────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  const _FilterChips({
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
                    : AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryContainer
                      : AppColors.outlineVariant,
                ),
              ),
              child: AppText(
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
