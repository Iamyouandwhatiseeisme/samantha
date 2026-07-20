import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';

Map<String, TextStyle> buildHighlightTheme(AppColors colors, ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;

  return {
    'root': TextStyle(
      fontFamily: colors.mono,
      fontSize: 13,
      height: 1.5,
      color: scheme.onSurface,
    ),
    'hljs-comment': TextStyle(
      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
      fontStyle: FontStyle.italic,
    ),
    'hljs-quote': TextStyle(
      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
      fontStyle: FontStyle.italic,
    ),
    'hljs-keyword': TextStyle(
      color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
    ),
    'hljs-selector-tag': TextStyle(
      color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
    ),
    'hljs-literal': TextStyle(
      color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
    ),
    'hljs-section': TextStyle(
      color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
    ),
    'hljs-link': TextStyle(
      color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
    ),
    'hljs-function': TextStyle(
      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    ),
    'hljs-title': TextStyle(
      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    ),
    'hljs-params': TextStyle(
      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    ),
    'hljs-string': TextStyle(
      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
    ),
    'hljs-subst': TextStyle(
      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
    ),
    'hljs-type': TextStyle(
      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
    ),
    'hljs-class': TextStyle(
      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
    ),
    'hljs-number': TextStyle(
      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
    ),
    'hljs-built_in': TextStyle(
      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
    ),
    'hljs-builtin_name': TextStyle(
      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
    ),
    'hljs-bullet': TextStyle(
      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
    ),
    'hljs-symbol': TextStyle(
      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
    ),
    'hljs-meta': TextStyle(
      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
    ),
    'hljs-variable': TextStyle(
      color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
    ),
    'hljs-template-variable': TextStyle(
      color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
    ),
    'hljs-attr': TextStyle(
      color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
    ),
    'hljs-attribute': TextStyle(
      color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
    ),
    'hljs-tag': TextStyle(
      color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
    ),
    'hljs-name': TextStyle(
      color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
    ),
    'hljs-operator': TextStyle(
      color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0891B2),
    ),
    'hljs-punctuation': TextStyle(
      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
    ),
    'hljs-regexp': TextStyle(
      color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0891B2),
    ),
    'hljs-deletion': TextStyle(
      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
      backgroundColor: isDark ? const Color(0xFF2A0808) : const Color(0xFFFEE2E2),
    ),
    'hljs-addition': TextStyle(
      color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A),
      backgroundColor: isDark ? const Color(0xFF0D2818) : const Color(0xFFDCFCE7),
    ),
  };
}
