import 'package:flutter/material.dart';

/// Design Tokens & Palette per Figma Specification (v3)
class TidaraPalette {
  final bool isDark;
  final bool highContrast;

  const TidaraPalette({required this.isDark, this.highContrast = false});

  Color get bgBase => isDark
      ? (highContrast ? const Color(0xFF0C0A09) : const Color(0xFF14110F))
      : (highContrast ? const Color(0xFFFFFFFF) : const Color(0xFFF4F0E8));

  Color get surfaceCard => isDark
      ? (highContrast ? const Color(0xFF24201C) : const Color(0xFF1F1B18))
      : (highContrast ? const Color(0xFFDCD6C9) : const Color(0xFFE8E2D5));

  Color get surfaceElevated => isDark
      ? (highContrast ? const Color(0xFF352F29) : const Color(0xFF292420))
      : const Color(0xFFFFFFFF);

  Color get surfaceDark =>
      isDark ? const Color(0xFFF4F0E8) : const Color(0xFF1C1917);

  Color get accentPrimary => highContrast
      ? (isDark ? const Color(0xFFFF6E40) : const Color(0xFF9E3312))
      : const Color(0xFFC24C27);

  Color get accentSolar => const Color(0xFFE58A38);

  Color get errorColor => isDark
      ? (highContrast ? const Color(0xFFFFB4AB) : const Color(0xFFFF897D))
      : (highContrast ? const Color(0xFF93000A) : const Color(0xFFBA1A1A));

  Color get strokeSubtle => isDark
      ? (highContrast ? const Color(0xFF574E46) : const Color(0xFF332E2A))
      : (highContrast ? const Color(0xFFB5AC99) : const Color(0xFFD9D2C3));

  Color get textPrimary =>
      isDark ? const Color(0xFFF4F0E8) : const Color(0xFF1C1917);

  Color get textSecondary => isDark
      ? (highContrast ? const Color(0xFFD6CFC5) : const Color(0xFFB8B0A4))
      : (highContrast ? const Color(0xFF3D3934) : const Color(0xFF5C5346));
}
