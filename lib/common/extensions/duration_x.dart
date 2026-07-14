extension DurationX on Duration {
  String toShortText() {
    if (inSeconds < 1) {
      return '${(inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    if (inSeconds < 60) return '${inSeconds}s';
    if (inMinutes < 60) return '${inMinutes}m ${inSeconds % 60}s';
    return '${inMinutes}m ${inSeconds % 60}s';
  }
}
