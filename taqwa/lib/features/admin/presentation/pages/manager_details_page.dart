import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/telegram.dart';
import '../../../data/models/manager_model.dart';
import '../../../data/repositories/manager_repository.dart';
import '../../../shared/presentation/widgets/profile_detail_widgets.dart';
import 'create_manager_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// A manager's profile as the admin sees it: contact details, the halaqas
/// they are responsible for, and what their account is allowed to do.
/// Opened by tapping a card in the admin managers list.
///
/// Pops `true` when the manager was edited from here, so the list behind it
/// knows to reload.
class ManagerDetailsPage extends StatefulWidget {
  const ManagerDetailsPage({super.key, required this.manager});

  /// The row from the list, rendered straight away. GET /managers returns the
  /// same include as GET /managers/:id, so there is nothing missing to wait
  /// for; the page only re-fetches on pull-to-refresh or after an edit.
  final ManagerModel manager;

  @override
  State<ManagerDetailsPage> createState() => _ManagerDetailsPageState();
}

class _ManagerDetailsPageState extends State<ManagerDetailsPage> {
  final _repo = ManagerRepository();
  late ManagerModel _manager = widget.manager;
  bool _changed = false;

  Future<void> _reload() async {
    final id = _manager.id;
    if (id == null) return;
    try {
      final fresh = await _repo.getManager(id);
      if (mounted) setState(() => _manager = fresh);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(ManagerRepository.errorMessage(e))),
      );
    }
  }

  Future<void> _openEdit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateManagerPage(editManager: _manager),
      ),
    );
    if (saved == true && mounted) {
      _changed = true;
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final halaqas = _manager.halaqas ?? const <Map<String, dynamic>>[];

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ProfileDetailHeader(
                  title: 'ملف المدير',
                  name: _manager.fullName,
                  avatar: _manager.avatar,
                  isActive: _manager.isActive ?? true,
                  onEdit: _openEdit,
                ),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailSectionCard(
                        title: 'معلومات التواصل',
                        children: [
                          DetailInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'رقم الهاتف',
                            value: _manager.phone,
                            isLtr: true,
                          ),
                          if (telegramUri(_manager.phone) != null) ...[
                            SizedBox(height: 12.h),
                            TelegramButton(phone: _manager.phone),
                          ],
                          SizedBox(height: 12.h),
                          DetailInfoRow(
                            icon: Icons.email_outlined,
                            label: 'البريد الإلكتروني',
                            value: _manager.email,
                            isLtr: true,
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      DetailSectionCard(
                        title: 'الحلقات المعينة (${halaqas.length})',
                        children: [
                          if (halaqas.isEmpty)
                            AppText(
                              'لم تُعيَّن أي حلقة لهذا المدير.',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            )
                          else
                            for (final halaqa in halaqas) ...[
                              _HalaqaTile(halaqa: halaqa),
                              if (halaqa != halaqas.last) SizedBox(height: 8.h),
                            ],
                        ],
                      ),
                      SizedBox(height: 16.h),
                      DetailSectionCard(
                        title: 'الصلاحيات والنشاط',
                        children: [
                          _PermissionRow(
                            label: 'إدارة الحسابات',
                            allowed: _manager.canManageAccounts,
                          ),
                          SizedBox(height: 8.h),
                          _PermissionRow(
                            label: 'حذف الحسابات',
                            allowed: _manager.canDeleteAccounts,
                          ),
                          SizedBox(height: 12.h),
                          DetailInfoRow(
                            icon: Icons.fact_check_outlined,
                            label: 'تبريرات الغياب المسجلة',
                            value: '${_manager.justificationsCount ?? 0}',
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One assigned halaqa: name, with its level as a chip when it has one.
class _HalaqaTile extends StatelessWidget {
  const _HalaqaTile({required this.halaqa});

  final Map<String, dynamic> halaqa;

  @override
  Widget build(BuildContext context) {
    final level = halaqa['level'] as String?;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          if (level != null && level.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: AppText(
                level,
                style: AppTextStyles.labelSm.copyWith(color: AppColors.primary),
              ),
            ),
          SizedBox(width: 8.w),
          Expanded(
            child: AppText(
              (halaqa['name'] as String?) ?? '',
              style: AppTextStyles.labelMdBold.copyWith(
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 12.w),
          const Icon(
            Icons.menu_book_outlined,
            size: 18,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// A permission the admin granted or withheld when creating the manager.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.allowed});

  final String label;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final color = allowed ? AppColors.primary : AppColors.outline;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: AppText(
            allowed ? 'مسموح' : 'غير مسموح',
            style: AppTextStyles.labelSm.copyWith(color: color),
          ),
        ),
        const Spacer(),
        AppText(
          label,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        ),
        SizedBox(width: 8.w),
        Icon(
          allowed ? Icons.check_circle_outline : Icons.block,
          size: 18,
          color: color,
        ),
      ],
    );
  }
}
