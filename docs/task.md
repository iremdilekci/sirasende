# SıraSende Proje Görev Listesi (task.md)

## Sprint 1 – Backend ve Veritabanı Temeli

### Gün 4 – İşletme API’leri
- [x] Pydantic şemalarının oluşturulması (`backend/app/schemas/business.py`)
  - [x] `BusinessListItem` (Temel işletme bilgileri şeması)
  - [x] `BusinessDetail` (Detaylı işletme bilgileri şeması)
- [x] Veritabanı oturum bağımlılığının kurulması (`backend/app/api/deps.py`)
  - [x] `get_db` generator fonksiyonu (`get_db_session` sarmalayıcısı)
- [x] İşletme uç noktalarının kodlanması (`backend/app/api/v1/businesses.py`)
  - [x] `GET /api/v1/businesses` (Aktif işletmeleri listeler)
  - [x] `GET /api/v1/businesses/{slug}` (Belirli işletmeyi getirir, yoksa 404)
- [x] API yönlendiricisinin kurulması (`backend/app/api/v1/router.py`)
- [x] `main.py` güncellemesi (API yönlendiricisinin `/api/v1` ile uygulamaya bağlanması)
- [x] İşletme API birim ve entegrasyon testlerinin yazılması (`backend/tests/test_businesses.py`)

### Gün 5 – Dinamik Slot Sistemi
- [x] Slot üretici servisinin yazılması (`backend/app/services/slot_service.py`)
  - [x] Mesai saatlerine göre 30, 45, 60 dakikalık dilimler oluşturulması
  - [x] Mesai bitiş saatini aşan slotların filtrelenmesi
  - [x] Geçmiş günlerin ve bugün içindeki geçmiş saatlerin pasif (`available: false`) yapılması
  - [x] Veritabanından o günün aktif (`pending`, `confirmed`) randevularının çekilerek çakışan slotların rezerve (`available: false`) olarak işaretlenmesi
- [x] Slot uç noktasının kodlanması (`backend/app/api/v1/businesses.py`)
  - [x] `GET /api/v1/businesses/{slug}/slots?date=YYYY-MM-DD`
- [x] Slot üretici mantığı için birim ve entegrasyon testlerinin yazılması (`backend/tests/test_slot_service.py`, `backend/tests/test_business_slots.py`)

### Gün 6 – Randevu Oluşturma ve Çakışma Engelleme
- [ ] Randevu Pydantic şemalarının oluşturulması (`backend/app/schemas/appointment.py`)
  - [ ] `AppointmentCreate` (İstek şeması)
  - [ ] `AppointmentOut` (Yanıt şeması)
- [ ] Veritabanı seviyesinde benzersizlik kuralı eklenmesi (Alembic Migration)
  - [ ] Aktif randevular (`pending` ve `confirmed` durumundakiler) için `(business_id, appointment_date, start_time)` kombinasyonuna `Partial Unique Index` eklenmesi
- [ ] Randevu oluşturma servisinin yazılması (`backend/app/services/appointment_service.py`)
  - [ ] Seçilen gün ve saatin uygunluk kontrolü
  - [ ] İşlem (transaction) yönetimiyle çakışma durumunda hata yönetimi
- [ ] Randevu oluşturma uç noktasının kodlanması
  - [ ] `POST /api/v1/businesses/{slug}/appointments` (Eş zamanlı istekte çakışma olursa `409 Conflict`)
- [ ] Eş zamanlı randevu oluşturma entegrasyon testlerinin yazılması

---

## Sprint 2 – Esnaf API’leri ve Mobil Temel

### Gün 7 – JWT Giriş Sistemi
- [ ] Şifre kontrolü ve JWT işlemleri için güvenlik yardımcısının yazılması (`backend/app/core/security.py`)
- [ ] Giriş Pydantic şemalarının hazırlanması (`backend/app/schemas/auth.py`)
- [ ] Giriş uç noktasının kodlanması (`backend/app/api/v1/auth.py`)
  - [ ] `POST /api/v1/auth/login`
- [ ] Giriş etmiş kullanıcıyı doğrulayan `get_current_user` bağımlılığının yazılması (`backend/app/api/deps.py`)
- [ ] Giriş sistemi için testlerin yazılması

### Gün 8 – Esnaf Randevu Yönetimi
- [ ] Esnaf randevu yönetim uç noktalarının kodlanması (`backend/app/api/v1/admin_appointments.py`)
  - [ ] `GET /api/v1/admin/appointments` (İşletmeye ait randevuları listeleme ve filtreleme)
  - [ ] `PATCH /api/v1/admin/appointments/{id}/status` (Durum güncelleme)
- [ ] Randevu durum değişim iş kurallarının kontrolü
  - [ ] Sadece izin verilen durum geçişleri (`pending` ➔ `confirmed`/`cancelled`, vb.)
  - [ ] Esnafın başka bir işletmeye ait randevuyu değiştirmesinin engellenmesi
- [ ] Esnaf randevu yönetimi için testlerin yazılması

### Gün 9 – Flutter Proje Temeli
- [ ] Flutter projesinin oluşturulması (`mobile/` dizininde)
- [ ] `pubspec.yaml` bağımlılıklerinin eklenmesi (`flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `intl`)
- [ ] Ağ katmanının kurulması (Dio istemcisi, hata yakalama, base URL yapılandırması)
- [ ] Rota altyapısının kurulması (`GoRouter`)
- [ ] Global tema, buton, input ve yükleme (loading) bileşenlerinin oluşturulması

### Gün 10 – Rol ve İşletme Ekranları
- [ ] Rol seçim ekranının yapılması (Müşteri / Esnaf seçimi)
- [ ] İşletme listeleme ekranının yapılması (Backend API'den çekilen verilerle)
- [ ] İşletme detay ekranının yapılması (Çalışma saatleri ve açıklama alanları ile)

### Gün 11 – Tarih ve Slot Seçimi
- [ ] Randevu tarihi seçici bileşeninin yazılması (Geçmiş günlerin engellenmesi)
- [ ] Slot listeleme ekranının yapılması
  - [ ] Müsait slotlar (aktif/seçilebilir)
  - [ ] Dolu ve geçmiş slotlar (pasif/seçilemez)
- [ ] Seçilen slot durumunun Riverpod ile yönetimi

---

## Sprint 3 – Mobil Randevu ve Esnaf Yönetimi

### Gün 12 – Randevu Formu
- [ ] Randevu bilgi giriş formunun tasarlanması (Müşteri Adı, Telefon, Not)
- [ ] Form doğrulama (validation) işlemlerinin eklenmesi
- [ ] Randevu oluşturma isteğinin backend'e gönderilmesi ve başarı/hata ekranları
- [ ] Başarılı randevu sonrası slot listesinin yenilenmesi

### Gün 13 – Esnaf Giriş Ekranı
- [ ] Esnaf giriş formunun yapılması
- [ ] Login API bağlantısı ve JWT token'ının `Flutter Secure Storage` ile saklanması
- [ ] Token kontrolü ve yetkisiz kullanıcıların login ekranına yönlendirilmesi (Route Guard)
- [ ] Çıkış (Logout) fonksiyonunun eklenmesi

### Gün 14 – Mobil Esnaf Randevu Paneli
- [ ] Gelen randevuları listeleme ekranı (Tarih ve saate göre sıralı)
- [ ] Randevu kartı tasarımı (Müşteri bilgileri, notlar, durum etiketleri)
- [ ] Durum değiştirme butonlarının eklenmesi (Onayla, İptal Et, Tamamlandı)
- [ ] Durum güncellendiğinde listenin otomatik yenilenmesi

### Gün 15 – Uçtan Uca Test ve Düzeltmeler
- [ ] Müşteri ve Esnaf akışlarının uçtan uca entegrasyon testleri
- [ ] Responsive tasarım ve taşma hatalarının düzeltilmesi
- [ ] Temizlik ve kod kalitesi kontrolü

---

## Sprint 4 – Bonus ve Entegrasyonlar (MVP Sonrası)

### Gün 16 – Google OAuth Kurulumu
- [ ] Google Cloud Console projesi ve OAuth kimlik bilgilerinin ayarlanması
- [ ] Backend Google OAuth yönlendirme ve callback endpoint'lerinin yazılması
- [ ] Refresh token'ların veritabanında güvenli saklanması

### Gün 17 – Google Calendar Entegrasyonu
- [ ] Esnafın onayladığı randevuların otomatik olarak Google Takvim'ine işlenmesi
- [ ] Randevu iptal/güncellemelerinde Google Takvim senkronizasyonunun yapılması

### Gün 18 – React Web Müşteri Arayüzü (Opsiyonel)
- [ ] React, TypeScript ve Tailwind CSS projesinin oluşturulması (`web/`)
  - [ ] İşletmeleri listeleme, detay görme, tarih/slot seçme ve randevu oluşturma akışının yapılması

---

## Backlog / Technical Debt

### TD-001 – PostgreSQL Async Test Stabilization

**Priority:** Medium

**Status:** Completed

**Description**

Sprint 1 / Gün 3 sonrasında PostgreSQL entegrasyon testlerinde aşağıdaki hata gözlemlendi:

`asyncpg.exceptions._base.InterfaceError: another operation is in progress`

Bu sorun yalnızca test ortamında görülmektedir. Uygulamanın çalışma zamanını (runtime) etkilemediği için MVP geliştirmesine devam edilmiştir.

**Resolution**

Testler arasında global `backend/tests/conftest.py` dosyasına eklenen autouse fixture ile `engine.dispose()` çağrılarak bağlantı havuzu temizlendi. Böylece kapalı event loop'lar üzerindeki eski soketlerin yeni event loop'ta kullanılmaya çalışılması engellendi ve testler stabilize edildi.

**Verification Note**

`22 passed, 0 failed, 0 skipped` sonucuna ulaşıldı.

**Potential Causes**

- AsyncSession'ın birden fazla coroutine tarafından paylaşılması
- Test fixture yaşam döngüsünün yanlış yönetilmesi
- Transaction rollback sırasındaki eşzamanlı işlemler
- Connection pool yapılandırması

**Acceptance Criteria**

- [x] Test fixture'ları gözden geçirilecek.
- [x] AsyncSession yönetimi düzeltilecek.
- [x] Transaction yönetimi doğrulanacak.
- [x] Backend testleri en az 10 kez art arda hatasız çalışacak.
- [x] `another operation is in progress` hatası tamamen giderilmiş olacak.

