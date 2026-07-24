class NetworkConstants {
  NetworkConstants._();

  /// Base URL of the API.
  ///
  /// 'http://10.0.2.2:8000' points to the host machine's localhost
  /// from the Android Emulator network interface context.
  static const baseUrl = 'http://10.0.2.2:8000';

  static const businesses = '/api/v1/businesses';

  static String businessBySlug(String slug) =>
      '$businesses/${Uri.encodeComponent(slug)}';

  static String businessSlots(String slug) =>
      '$businesses/${Uri.encodeComponent(slug)}/slots';

  static String createAppointment(String slug) =>
      '$businesses/${Uri.encodeComponent(slug)}/appointments';

  static const login = '/api/v1/auth/login';
  static const me = '/api/v1/auth/me';
  static const adminAppointments = '/api/v1/admin/appointments';
  static const adminBusiness = '/api/v1/admin/business';
  static const googleCalendarStatus = '/api/v1/admin/google-calendar/status';
  static const googleCalendarConnect = '/api/v1/admin/google-calendar/connect';
  static const googleCalendarConnection =
      '/api/v1/admin/google-calendar/connection';
}
