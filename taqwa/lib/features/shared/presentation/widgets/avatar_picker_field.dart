import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';

/// Circular avatar the user taps to pick a photo from the gallery or camera.
///
/// Purely a picker: it hands the chosen [XFile] back through [onPicked] and
/// never uploads anything. Callers upload to the API when the form is
/// submitted, so abandoning a form costs nothing.
///
/// On an edit form pass [existingUrl] so the stored avatar shows until the
/// user picks a replacement.
class AvatarPickerField extends StatelessWidget {
  const AvatarPickerField({
    super.key,
    required this.picked,
    required this.onPicked,
    this.existingUrl,
    this.label = 'الصورة الشخصية',
    this.emptyHint = 'انقر لاختيار صورة (اختياري)',
  });

  final XFile? picked;
  final ValueChanged<XFile> onPicked;
  final String? existingUrl;
  final String label;
  final String emptyHint;

  bool get _hasImage => picked != null || (existingUrl?.isNotEmpty ?? false);

  Future<void> _showSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: AppText('اختيار من المعرض', style: AppTextStyles.bodyMd),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: AppText('التقاط صورة بالكاميرا', style: AppTextStyles.bodyMd),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final img = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: AppConstants.pickedImageMaxDimension,
      maxHeight: AppConstants.pickedImageMaxDimension,
    );
    if (img != null) onPicked(img);
  }

  /// The freshly picked file wins over the stored URL, so the preview updates
  /// the moment the user chooses a new photo.
  DecorationImage? _image() {
    final file = picked;
    if (file != null) {
      return DecorationImage(image: FileImage(File(file.path)), fit: BoxFit.cover);
    }
    final url = existingUrl;
    if (url != null && url.isNotEmpty) {
      return DecorationImage(image: NetworkImage(ApiEndpoints.mediaUrl(url)), fit: BoxFit.cover);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: () => _showSourceSheet(context),
            child: Stack(
              children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    image: _image(),
                  ),
                  child: _hasImage
                      ? null
                      : Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.onSurfaceVariant,
                          size: 36.w,
                        ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _hasImage ? Icons.check : Icons.edit,
                      color: AppColors.onPrimary,
                      size: 16.w,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: Column(
            children: [
              AppText(
                label,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              AppText(
                picked != null ? 'تم اختيار صورة' : emptyHint,
                style: AppTextStyles.labelSm.copyWith(
                  color: picked != null
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
