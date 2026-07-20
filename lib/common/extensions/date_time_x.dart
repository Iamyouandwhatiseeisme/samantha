import 'package:flutter/widgets.dart';
import 'package:samantha/common/extensions/context_x.dart';

extension DateTimeX on DateTime {
  String toTimeString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String toRelative(BuildContext context) {
    if (millisecondsSinceEpoch == 0) return '';
    final diff = DateTime.now().difference(this);
    if (diff.inMinutes < 60) return '${diff.inMinutes}${context.l10n.minutesAgo}';
    if (diff.inHours < 24) return '${diff.inHours}${context.l10n.hoursAgo}';
    if (diff.inDays < 7) return '${diff.inDays}${context.l10n.daysAgo}';
    return '$month/$day';
  }
}
