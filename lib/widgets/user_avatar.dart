import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final VoidCallback? onTap;

  const UserAvatar({super.key, this.url, this.size = 32, this.onTap});

  @override
  Widget build(BuildContext context) {
    final widget = ClipOval(
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }
    return widget;
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: AppColors.border,
        child: Icon(Icons.person, size: size * 0.6, color: AppColors.textSecondary),
      );
}
