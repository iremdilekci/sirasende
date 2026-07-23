import 'package:sirasende_mobile/features/business/data/datasources/google_calendar_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connect_result.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connection_status.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/google_calendar_repository.dart';

class GoogleCalendarRepositoryImpl implements GoogleCalendarRepository {
  final GoogleCalendarRemoteDataSource _remoteDataSource;

  GoogleCalendarRepositoryImpl(this._remoteDataSource);

  @override
  Future<GoogleCalendarConnectionStatus> getConnectionStatus() {
    return _remoteDataSource.fetchConnectionStatus();
  }

  @override
  Future<GoogleCalendarConnectResult> getConnectUrl() {
    return _remoteDataSource.fetchConnectUrl();
  }

  @override
  Future<void> disconnect() {
    return _remoteDataSource.deleteConnection();
  }
}
