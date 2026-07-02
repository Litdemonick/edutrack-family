import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ═══════════════════════════════════════════════════════════════
// CACHED LOCAL IMAGE — EduTrack Family
// Muestra una imagen desde la web (usando caché) o desde un
// archivo local, dependiendo de la ruta proporcionada.
// ═══════════════════════════════════════════════════════════════

class CachedLocalImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CachedLocalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey.withValues(alpha: 0.15),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey.withValues(alpha: 0.15),
          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        ),
      );
    }

    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.withValues(alpha: 0.15),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: Colors.grey.withValues(alpha: 0.15),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      ),
    );
  }
}
