class GoogleCalendarConnectResult {
  final String authorizationUrl;

  const GoogleCalendarConnectResult({
    required this.authorizationUrl,
  });

  factory GoogleCalendarConnectResult.fromJson(Map<String, dynamic> json) {
    return GoogleCalendarConnectResult(
      authorizationUrl: json['authorization_url'] as String? ?? '',
    );
  }
}
