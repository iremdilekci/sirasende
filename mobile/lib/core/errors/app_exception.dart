class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() {
    if (code != null) {
      return 'AppException[$code]: $message';
    }
    return 'AppException: $message';
  }
}
