import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_profile_screen.dart';
import 'package:sirasende_mobile/features/business/presentation/screens/business_detail_screen.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_form_screen.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_form_args.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connection_status.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connect_result.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/google_calendar_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/google_calendar_providers.dart';

class FakeBusinessRepository implements BusinessRepository {
  List<Business> businesses = [];
  Business? businessResult;
  List<Slot> slots = [];
  Object? error;
  int getAdminCount = 0;
  List<BusinessSchedule>? lastUpdateSchedules;

  @override
  Future<List<Business>> getBusinesses() async {
    if (error != null) throw error!;
    return businesses;
  }

  @override
  Future<Business> getBusinessBySlug(String slug) async {
    if (error != null) throw error!;
    return businessResult!;
  }

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async {
    if (error != null) throw error!;
    return slots;
  }

  @override
  Future<Business> getAdminBusiness() async {
    getAdminCount++;
    if (error != null) throw error!;
    return businessResult!;
  }

  @override
  Future<Business> updateAdminBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
    List<BusinessSchedule>? schedules,
  }) async {
    lastUpdateSchedules = schedules;
    if (error != null) throw error!;
    return businessResult!;
  }
}

class FakeAppointmentRepository implements AppointmentRepository {
  List<Appointment> adminAppointments = [];
  bool throw409 = false;
  int createCalls = 0;
  int updateCalls = 0;
  String? lastUpdateId;
  String? lastUpdateStatus;

  @override
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  }) async {
    createCalls++;
    if (throw409) {
      throw const AppException(
        message: 'Bu slot için zaten aktif bir randevu bulunmaktadır.',
        code: 'CONFLICT',
      );
    }
    return Appointment(
      id: 'app-1',
      businessId: '1',
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      customerNote: request.customerNote,
      appointmentDate: request.appointmentDate,
      startTime: request.startTime,
      endTime: '10:00:00',
      status: 'pending',
      createdAt: '2026-07-22T10:00:00Z',
      updatedAt: '2026-07-22T10:00:00Z',
    );
  }

  @override
  Future<List<Appointment>> getAdminAppointments({
    String? date,
    String? status,
  }) async {
    return adminAppointments;
  }

  @override
  Future<Appointment> updateAppointmentStatus({
    required String id,
    required String status,
  }) async {
    updateCalls++;
    lastUpdateId = id;
    lastUpdateStatus = status;
    return Appointment(
      id: id,
      businessId: '1',
      customerName: 'Test Customer',
      customerPhone: '+905554443322',
      appointmentDate: '2026-07-22',
      startTime: '09:00:00',
      endTime: '09:30:00',
      status: status,
      createdAt: '2026-07-22T09:00:00Z',
      updatedAt: '2026-07-22T09:00:00Z',
    );
  }

  @override
  Future<Appointment> syncGoogleCalendar({required String id}) async {
    return Appointment(
      id: id,
      businessId: '1',
      customerName: 'Test Customer',
      customerPhone: '+905554443322',
      appointmentDate: '2026-07-22',
      startTime: '09:00:00',
      endTime: '09:30:00',
      status: 'confirmed',
      createdAt: '2026-07-22T09:00:00Z',
      updatedAt: '2026-07-22T09:00:00Z',
      calendarSyncStatus: 'synced',
      calendarEventCreated: true,
    );
  }
}

class FakeAuthRepository implements AuthRepository {
  String? token = 'mock-token';
  AdminUser? currentUser = const AdminUser(
    id: '1',
    businessId: '1',
    username: 'demo_admin',
    email: 'demo@example.com',
    isActive: true,
  );
  bool throwOnLogin = false;
  bool throwOnGetMe = false;

  @override
  Future<TokenResponse> login(LoginRequest request) async {
    if (throwOnLogin) {
      throw const AppException(
        message: 'Geçersiz kullanıcı adı veya şifre.',
        code: 'UNAUTHORIZED',
      );
    }
    return const TokenResponse(
      accessToken: 'mock-token',
      tokenType: 'bearer',
      expiresIn: 3600,
    );
  }

  @override
  Future<AdminUser> getMe() async {
    if (throwOnGetMe) {
      throw const AppException(
        message: 'Oturum süresi doldu.',
        code: 'UNAUTHORIZED',
      );
    }
    return currentUser!;
  }

  @override
  Future<void> saveToken(String t) async {
    token = t;
  }

  @override
  Future<String?> getToken() async {
    return token;
  }

  @override
  Future<void> deleteToken() async {
    token = null;
  }
}

class FakeGoogleCalendarRepository implements GoogleCalendarRepository {
  GoogleCalendarConnectionStatus? statusResult;
  GoogleCalendarConnectResult? connectResult;
  Object? error;

  int statusCalls = 0;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<GoogleCalendarConnectionStatus> getConnectionStatus() async {
    statusCalls++;
    if (error != null) throw error!;
    return statusResult ??
        const GoogleCalendarConnectionStatus(connected: false);
  }

  @override
  Future<GoogleCalendarConnectResult> getConnectUrl() async {
    connectCalls++;
    if (error != null) throw error!;
    return connectResult!;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (error != null) throw error!;
  }
}

void main() {
  group('MVP E2E Stabilization Tests', () {
    late FakeBusinessRepository fakeBusinessRepo;
    late FakeAppointmentRepository fakeAppointmentRepo;
    late FakeAuthRepository fakeAuthRepo;

    final dummyBusiness = const Business(
      id: '1',
      name: 'Berber Ahmet',
      slug: 'berber-ahmet',
      address: 'Kadikoy, Istanbul',
      phone: '+905554443322',
      slotDurationMinutes: 30,
      isActive: true,
      workingStartTime: '09:00:00',
      workingEndTime: '18:00:00',
      schedules: [
        BusinessSchedule(
          dayOfWeek: 0,
          startTime: '09:00:00',
          endTime: '18:00:00',
          isClosed: false,
        ),
        BusinessSchedule(
          dayOfWeek: 1,
          startTime: '09:00:00',
          endTime: '18:00:00',
          isClosed: false,
        ),
        BusinessSchedule(
          dayOfWeek: 2,
          startTime: '09:00:00',
          endTime: '18:00:00',
          isClosed: false,
        ),
        BusinessSchedule(
          dayOfWeek: 3,
          startTime: '09:00:00',
          endTime: '18:00:00',
          isClosed: false,
        ),
        BusinessSchedule(
          dayOfWeek: 4,
          startTime: '09:00:00',
          endTime: '18:00:00',
          isClosed: false,
        ),
        BusinessSchedule(
          dayOfWeek: 5,
          startTime: '09:00:00',
          endTime: '18:00:00',
          isClosed: false,
        ),
        BusinessSchedule(
          dayOfWeek: 6,
          startTime: '09:00:00',
          endTime: '18:00:00',
          isClosed: false,
        ),
      ],
    );

    late FakeGoogleCalendarRepository fakeGoogleCalendarRepo;

    setUp(() {
      fakeBusinessRepo = FakeBusinessRepository();
      fakeAppointmentRepo = FakeAppointmentRepository();
      fakeAuthRepo = FakeAuthRepository();
      fakeGoogleCalendarRepo = FakeGoogleCalendarRepository();

      fakeBusinessRepo.businessResult = dummyBusiness;
      fakeBusinessRepo.businesses = [dummyBusiness];
    });

    Widget makeTestableWidget(Widget child) {
      return ProviderScope(
        overrides: [
          businessRepositoryProvider.overrideWithValue(fakeBusinessRepo),
          appointmentRepositoryProvider.overrideWithValue(fakeAppointmentRepo),
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          googleCalendarRepositoryProvider.overrideWithValue(
            fakeGoogleCalendarRepo,
          ),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('Onboarding screen displays client and admin choices', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidget(const RoleSelectionScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Müşteri olarak devam et'), findsOneWidget);
      expect(find.text('Esnaf olarak devam et'), findsOneWidget);
    });

    testWidgets('Client list renders empty state when list is empty', (
      tester,
    ) async {
      fakeBusinessRepo.businesses = [];
      await tester.pumpWidget(
        makeTestableWidget(const CustomerBusinessListScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Henüz işletme bulunmuyor'), findsOneWidget);
    });

    testWidgets('Client list renders businesses list properly', (tester) async {
      fakeBusinessRepo.businesses = [dummyBusiness];
      await tester.pumpWidget(
        makeTestableWidget(const CustomerBusinessListScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Berber Ahmet'), findsOneWidget);
    });

    testWidgets('Client detail picking and appointment validation checks', (
      tester,
    ) async {
      fakeBusinessRepo.slots = [
        const Slot(startTime: '09:00:00', endTime: '09:30:00', available: true),
      ];

      await tester.pumpWidget(
        makeTestableWidget(const BusinessDetailScreen(slug: 'berber-ahmet')),
      );
      await tester.pump();
      await tester.pump();

      // Check business detail text
      expect(find.text('Berber Ahmet'), findsWidgets);

      // Date Picker selected and slots loaded
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('Appointment booking conflict 409 shows Turkish error', (
      tester,
    ) async {
      fakeAppointmentRepo.throw409 = true;

      final args = AppointmentFormArgs(
        businessSlug: 'berber-ahmet',
        businessName: 'Berber Ahmet',
        date: '2026-07-22',
        startTime: '09:00:00',
        endTime: '09:30:00',
      );

      await tester.pumpWidget(
        makeTestableWidget(AppointmentFormScreen(args: args)),
      );
      await tester.pump();

      // Doldur
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'Ahmet Yilmaz',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefon Numarası'),
        '05554443322',
      );

      // Tıkla
      await tester.ensureVisible(find.text('Randevuyu Oluştur'));
      await tester.tap(find.text('Randevuyu Oluştur'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Bu slot için zaten aktif bir randevu bulunmaktadır.'),
        findsOneWidget,
      );
    });

    testWidgets('Admin login triggers error message on failure', (
      tester,
    ) async {
      fakeAuthRepo.throwOnLogin = true;

      await tester.pumpWidget(makeTestableWidget(const AdminLoginScreen()));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kullanıcı adı veya e-posta'),
        'wrong@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'wrongpassword',
      );

      await tester.tap(find.text('Giriş Yap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Geçersiz kullanıcı adı veya şifre.'), findsOneWidget);
    });

    testWidgets('Admin profile weekly schedule closed day behavior', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidget(const AdminProfileScreen()));
      await tester.pump();
      await tester.pump();

      // Tap on 'Saatleri Düzenle' to open schedules view
      final editBtn = find.text('Saatleri Düzenle');
      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Find switch for Pazartesi and toggle it off
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pump();

      // Re-read switch value to make sure it is updated
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
    });
  });
}
