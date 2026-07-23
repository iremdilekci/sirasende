import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/dio_provider.dart';
import 'package:sirasende_mobile/features/appointment/data/datasources/appointment_remote_data_source.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/data/repositories/appointment_repository_impl.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';

class AppointmentController extends AsyncNotifier<Appointment?> {
  @override
  FutureOr<Appointment?> build() {
    return null;
  }

  Future<void> bookAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
    void Function(Appointment)? onSuccess,
  }) async {
    if (state.isLoading) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(appointmentRepositoryProvider);
      final appointment = await repository.createAppointment(
        businessSlug: businessSlug,
        request: request,
      );
      onSuccess?.call(appointment);
      return appointment;
    });
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final appointmentRemoteDataSourceProvider =
    Provider<AppointmentRemoteDataSource>((ref) {
      final dio = ref.watch(dioProvider);
      return AppointmentRemoteDataSource(dio);
    });

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  final remoteDataSource = ref.watch(appointmentRemoteDataSourceProvider);
  return AppointmentRepositoryImpl(remoteDataSource);
});

final appointmentControllerProvider =
    AsyncNotifierProvider.autoDispose<AppointmentController, Appointment?>(
      AppointmentController.new,
    );

class AdminAppointmentsParams {
  final String? date;
  final String? status;

  const AdminAppointmentsParams({this.date, this.status});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminAppointmentsParams &&
        other.date == date &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(date, status);
}

final adminAppointmentsProvider = FutureProvider.autoDispose
    .family<List<Appointment>, AdminAppointmentsParams>((ref, params) async {
      final repository = ref.watch(appointmentRepositoryProvider);
      return repository.getAdminAppointments(
        date: params.date,
        status: params.status,
      );
    });

class AdminAppointmentActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // idle state
  }

  Future<void> updateStatus({
    required String id,
    required String status,
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) async {
    if (state.isLoading) return;

    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final repository = ref.read(appointmentRepositoryProvider);
      await repository.updateAppointmentStatus(id: id, status: status);
    });

    if (result.hasError) {
      final error = result.error;
      final message = error is AppException
          ? error.message
          : 'İşlem gerçekleştirilirken bir sorun oluştu. Lütfen tekrar deneyin.';
      state = AsyncValue.error(
        error ?? message,
        result.stackTrace ?? StackTrace.current,
      );
      onError(message);
    } else {
      state = const AsyncValue.data(null);
      onSuccess();
    }
  }
}

final adminAppointmentActionControllerProvider =
    AsyncNotifierProvider.autoDispose<AdminAppointmentActionController, void>(
      AdminAppointmentActionController.new,
    );
