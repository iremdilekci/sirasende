import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connect_result.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connection_status.dart';

abstract class GoogleCalendarRepository {
  Future<GoogleCalendarConnectionStatus> getConnectionStatus();
  Future<GoogleCalendarConnectResult> getConnectUrl();
  Future<void> disconnect();
}
