import 'package:flutter/material.dart';

extension StringX on String {
  IconData get toToolIcon {
    switch (this) {
      case 'read':
        return Icons.menu_book;
      case 'write':
        return Icons.edit;
      case 'edit':
        return Icons.edit_note;
      case 'bash':
        return Icons.terminal;
      case 'glob':
        return Icons.search;
      case 'grep':
        return Icons.find_in_page;
      default:
        return Icons.build;
    }
  }
}
