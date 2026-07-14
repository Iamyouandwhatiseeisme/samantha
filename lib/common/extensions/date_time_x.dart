extension DateTimeX on DateTime {
  String toTimeString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String toRelative() {
    if (millisecondsSinceEpoch == 0) return '';
    final diff = DateTime.now().difference(this);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '$month/$day';
  }
}
