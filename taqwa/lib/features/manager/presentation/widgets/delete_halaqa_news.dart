import 'package:flutter/material.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_announcement_repository.dart';

/// Asks before deleting one piece of halaqa news, then deletes it.
///
/// Returns `true` once the server has dropped it, so the caller reloads. The
/// outcome is reported in a snackbar either way; shared by the news history
/// page and the admin and manager dashboards so all three say the same thing.
Future<bool> deleteHalaqaNews(
  BuildContext context,
  HalaqaAnnouncementModel announcement,
) async {
  final confirmed = await ConfirmDeleteDialog.show(
    context,
    // An all-halaqas post goes as one, from every halaqa it reached.
    message: announcement.batchId != null
        ? 'سيُحذف هذا الخبر من كل الحلقات التي نُشر فيها. لا يمكن التراجع عن هذا الإجراء.'
        : 'هل تريد حذف هذا الخبر؟ لا يمكن التراجع عن هذا الإجراء.',
  );
  if (!confirmed || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  void show(String message, {bool isError = false}) {
    messenger.showSnackBar(
      SnackBar(
        content: AppText(message, textAlign: TextAlign.right),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  try {
    await HalaqaAnnouncementRepository().delete(announcement.id);
    show('تم حذف الخبر');
    return true;
  } catch (e) {
    show(HalaqaAnnouncementRepository.errorMessage(e), isError: true);
    return false;
  }
}
