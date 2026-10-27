import 'package:flutter/material.dart';

/// The Taqwa dome, sized by its height since the artwork is taller than wide.
///
/// The asset is cropped to the dome itself, so it lines up with neighbouring
/// text without an invisible margin pushing it off centre.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.height});

  static const String assetPath = 'assets/images/logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'التقوى',
    );
  }
}
