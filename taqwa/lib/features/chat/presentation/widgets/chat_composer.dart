import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/app_text_field.dart';

/// The bottom bar of a thread: text, an optional photo, and send.
///
/// [onSend] returns whether the message went through. Only then is the text
/// cleared, so a failed send never loses what the person typed. The button is
/// disabled while a send is in flight, so a double tap can't send twice.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.hint,
    required this.onSend,
    this.onPickPhoto,
    this.editingText,
    this.onCancelEdit,
  });

  final String hint;
  final Future<bool> Function(String text, XFile? photo) onSend;

  /// Null hides the photo button.
  final Future<XFile?> Function()? onPickPhoto;

  /// Set while editing an existing message: prefills the field and hides the
  /// photo button (only text can be edited).
  final String? editingText;
  final VoidCallback? onCancelEdit;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  XFile? _photo;
  bool _sending = false;

  bool get _editing => widget.editingText != null;

  bool get _canSend =>
      !_sending &&
      (_controller.text.trim().isNotEmpty || (!_editing && _photo != null));

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    if (_editing) _controller.text = widget.editingText!;
  }

  @override
  void didUpdateWidget(ChatComposer old) {
    super.didUpdateWidget(old);
    if (widget.editingText != old.editingText) {
      _controller.text = widget.editingText ?? '';
      if (_editing) _photo = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final ok = await widget.onSend(_controller.text.trim(), _photo);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _controller.clear();
        _photo = null;
      }
    });
  }

  Future<void> _pickPhoto() async {
    final photo = await widget.onPickPhoto?.call();
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
      ),
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_editing) _buildEditBanner(),
            if (_photo != null) _buildPhotoPreview(_photo!),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildSendButton(),
                SizedBox(width: 6.w),
                Expanded(
                  child: AppTextField(
                    controller: _controller,
                    hint: widget.hint,
                    minLines: 1,
                    maxLines: 5,
                    // The server's limit; a counter under the field would be clutter.
                    inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                if (widget.onPickPhoto != null && !_editing) ...[
                  SizedBox(width: 6.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: IconButton(
                      tooltip: 'إرفاق صورة',
                      onPressed: _sending ? null : _pickPhoto,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainer,
                      ),
                      icon: Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.primary,
                        size: 22.w,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: IconButton(
        key: const Key('chat-send'),
        tooltip: _editing ? 'حفظ التعديل' : 'إرسال',
        onPressed: _canSend ? _send : null,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.surfaceContainerHigh,
        ),
        icon: _sending
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(
                _editing ? Icons.check : Icons.send,
                // The app tree is left-to-right; the arrow points the way
                // Arabic reads.
                textDirection: TextDirection.rtl,
                color: _canSend ? AppColors.onPrimary : AppColors.outline,
                size: 22.w,
              ),
      ),
    );
  }

  Widget _buildEditBanner() {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          IconButton(
            tooltip: 'إلغاء التعديل',
            onPressed: widget.onCancelEdit,
            icon: Icon(Icons.close, size: 20.w, color: AppColors.outline),
          ),
          const Spacer(),
          AppText(
            'تعديل الرسالة',
            style: AppTextStyles.labelMdBold.copyWith(color: AppColors.primary),
          ),
          SizedBox(width: 6.w),
          Icon(Icons.edit_outlined, size: 18.w, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(XFile photo) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Align(
        alignment: Alignment.centerRight,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: FutureBuilder(
                future: photo.readAsBytes(),
                builder: (_, snap) => snap.hasData
                    ? Image.memory(
                        snap.data!,
                        width: 88.w,
                        height: 88.w,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 88.w,
                        height: 88.w,
                        color: AppColors.surfaceContainer,
                      ),
              ),
            ),
            Positioned(
              top: 2,
              left: 2,
              child: Material(
                color: AppColors.onSurface.withValues(alpha: 0.6),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : () => setState(() => _photo = null),
                  child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Semantics(
                      label: 'إزالة الصورة',
                      child: Icon(
                        Icons.close,
                        size: 16.w,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
