import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:upendo_pamoja/domain.dart';

/// Profile photos. Blur until mutual when the member turns that setting on.
class PrivacyPhoto extends StatelessWidget {
  const PrivacyPhoto({
    super.key,
    required this.bytes,
    required this.revealed,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.showLock = true,
  });

  final Uint8List? bytes;
  final bool revealed;
  final BoxFit fit;
  final Widget? placeholder;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    final child = bytes == null
        ? (placeholder ?? const ColoredBox(color: Color(0xFFE7DCCB), child: Icon(Icons.person, color: Color(0xFF44403C))))
        : Image.memory(bytes!, fit: fit, width: double.infinity, height: double.infinity, gaplessPlayback: true);
    if (!ProfileDraft.blurUntilMutual || revealed) return child;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Transform.scale(scale: 1.12, child: child),
          ),
          const ColoredBox(color: Color(0x66FFFDF8)),
          if (showLock)
            const Center(
              child: Icon(Icons.lock_outline, color: Color(0xFFFFFDF8), size: 22),
            ),
        ],
      ),
    );
  }
}
