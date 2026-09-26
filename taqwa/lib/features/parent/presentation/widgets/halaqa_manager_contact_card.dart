import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../data/models/parent/halaqa_manager_contact_model.dart';

/// One row per manager of the child's halaqa: their name and a button that
/// opens a WhatsApp chat with them. Renders nothing when there is no one to
/// contact, so callers can drop it in unconditionally.
class HalaqaManagerContactCard extends StatelessWidget {
  const HalaqaManagerContactCard({super.key, required this.managers});

  final List<HalaqaManagerContactModel> managers;

  @override
  Widget build(BuildContext context) {
    if (managers.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < managers.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.surfaceVariant),
            _ManagerRow(
              manager: managers[i],
              onContact: () => openWhatsapp(context, managers[i].phone),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerRow extends StatelessWidget {
  const _ManagerRow({required this.manager, required this.onContact});

  final HalaqaManagerContactModel manager;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onContact,
            style: FilledButton.styleFrom(
              backgroundColor: kWhatsappGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
            ),
            icon: Icon(Icons.chat, size: 18.w),
            label: AppText(
              'واتساب',
              style: AppTextStyles.labelMdBold.copyWith(color: Colors.white),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  manager.fullName.isEmpty ? 'مشرف الحلقة' : manager.fullName,
                  style: AppTextStyles.bodyMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppText(
                  'مشرف الحلقة',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          CircleAvatar(
            radius: 20.w,
            backgroundColor: AppColors.primaryContainer,
            child: Icon(
              Icons.support_agent,
              color: AppColors.onPrimaryContainer,
              size: 22.w,
            ),
          ),
        ],
      ),
    );
  }
}
