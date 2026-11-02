import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';

/// A chat photo. Chat photos are private, so unlike avatars they are fetched
/// with the signed-in user's token; the server checks the thread's scope.
class ChatPhoto extends StatefulWidget {
  const ChatPhoto({super.key, required this.url});

  final String url;

  @override
  State<ChatPhoto> createState() => _ChatPhotoState();
}

class _ChatPhotoState extends State<ChatPhoto> {
  late final Future<String?> _token = appSecureStorage.read(key: 'jwt_token');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _token,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _frame(const _Loading());
        }
        final headers = {'Authorization': 'Bearer ${snap.data ?? ''}'};
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _FullScreenPhoto(url: widget.url, headers: headers),
            ),
          ),
          child: Semantics(
            label: 'صورة، اضغط للتكبير',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: Image.network(
                widget.url,
                headers: headers,
                width: 200.w,
                height: 150.w,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _frame(const _Loading()),
                errorBuilder: (_, _, _) => _frame(
                  Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.outline,
                    size: 32.w,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _frame(Widget child) => Container(
    width: 200.w,
    height: 150.w,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
    ),
    alignment: Alignment.center,
    child: child,
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 24,
    height: 24,
    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
  );
}

class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(url, headers: headers),
        ),
      ),
    );
  }
}
