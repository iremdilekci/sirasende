class GoogleCalendarConnectionStatus {
  final bool connected;
  final String? googleAccountEmail;
  final DateTime? connectedAt;
  final String? grantedScopes;

  const GoogleCalendarConnectionStatus({
    required this.connected,
    this.googleAccountEmail,
    this.connectedAt,
    this.grantedScopes,
  });

  factory GoogleCalendarConnectionStatus.fromJson(Map<String, dynamic> json) {
    final connected = json['connected'] as bool? ?? false;
    final email = json['google_account_email'] as String?;
    final connectedAtStr = json['connected_at'] as String?;
    final scopes = json['granted_scopes'] as String?;

    DateTime? parsedConnectedAt;
    if (connectedAtStr != null) {
      try {
        parsedConnectedAt = DateTime.parse(connectedAtStr).toLocal();
      } catch (_) {}
    }

    return GoogleCalendarConnectionStatus(
      connected: connected,
      googleAccountEmail: email,
      connectedAt: parsedConnectedAt,
      grantedScopes: scopes,
    );
  }
}
