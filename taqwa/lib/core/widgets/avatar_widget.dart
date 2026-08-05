import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Circular avatar that shows the student's photo when [avatarUrl] is set,
/// falling back to [fallback] (initial letter, index, icon...) when there's
/// no URL or the image fails to load.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.avatarUrl,
    required this.size,
    required this.fallback,
    this.backgroundColor = AppColors.primaryContainer,
  });

  final String? avatarUrl;
  final double size;
  final Widget fallback;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url.isEmpty)
          ? Center(child: fallback)
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(child: fallback),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(child: fallback);
              },
            ),
    );
  }
}
