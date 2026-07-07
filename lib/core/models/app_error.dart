class AppError {
  final String message;
  final dynamic original;

  const AppError({required this.message, this.original});

  @override
  String toString() => message;
}
