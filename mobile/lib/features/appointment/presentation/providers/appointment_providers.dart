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

class DashboardSummary {
  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;

  const DashboardSummary({
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
  });

  factory DashboardSummary.fromAppointments(List<Appointment> appointments) {
    int pending = 0;
    int confirmed = 0;
    int completed = 0;
    int cancelled = 0;

    for (final app in appointments) {
      switch (app.status) {
        case 'pending':
          pending++;
          break;
        case 'confirmed':
          confirmed++;
          break;
        case 'completed':
          completed++;
          break;
        case 'cancelled':
          cancelled++;
          break;
      }
    }

    return DashboardSummary(
      total: appointments.length,
      pending: pending,
      confirmed: confirmed,
      completed: completed,
      cancelled: cancelled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardSummary &&
        other.total == total &&
        other.pending == pending &&
        other.confirmed == confirmed &&
        other.completed == completed &&
        other.cancelled == cancelled;
  }

  @override
  int get hashCode =>
      Object.hash(total, pending, confirmed, completed, cancelled);
}

final todayDateStringProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
});

final adminDashboardSummaryProvider = Provider.autoDispose
    .family<AsyncValue<DashboardSummary>, String>((ref, date) {
      final params = AdminAppointmentsParams(date: date);
      final appointmentsAsync = ref.watch(adminAppointmentsProvider(params));

      return appointmentsAsync.when(
        data: (list) =>
            AsyncValue.data(DashboardSummary.fromAppointments(list)),
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    });
