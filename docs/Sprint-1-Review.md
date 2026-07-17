# Sprint 1 Review

## Sprint Goal
Sprint 1'in amacı, SıraSende projesi için ölçeklenebilir bir FastAPI backend altyapısı oluşturmak, PostgreSQL tabanlı veri katmanını kurmak ve güvenli randevu oluşturma iş akışını testlerle birlikte tamamlamaktır.

---

## Completed Features
Sprint 1 kapsamında başarıyla tamamlanan ve doğrulanan özellikler:
- **FastAPI backend foundation:** Güçlü, asenkron ve yapılandırılmış FastAPI uygulama iskeletinin kurulması.
- **PostgreSQL integration:** Güvenilir ve ilişkisel veri depolama için PostgreSQL veritabanı entegrasyonu.
- **SQLAlchemy async models:** Asenkron veri tabanı işlemleri için SQLAlchemy asenkron ORM modellerinin tanımlanması.
- **Alembic migration system:** Veritabanı şema değişikliklerinin kontrolü için Alembic göç altyapısının kurulması.
- **Docker development environment:** Geliştiriciler için izole ve taşınabilir Docker Compose geliştirme ortamı.
- **Health endpoints:** Uygulama ve veritabanı sağlığını izleyen denetim uç noktalarının kodlanması.
- **Business API:** İşletmelerin aktif durumlarına göre listelenmesi ve detay bilgilerinin sorgulanması.
- **Dynamic slot generation:** İşletme mesai saatlerine göre 30, 45 veya 60 dakikalık dinamik zaman slotlarının üretimi.
- **Slot availability endpoint:** İlgili tarihteki dolu, geçmiş veya müsait slotları getiren HTTP endpoint entegrasyonu.
- **Appointment creation endpoint:** İstemcilerin belirli bir slot için randevu kaydı oluşturmasını sağlayan API.
- **Conflict-safe booking:** Çakışan eş zamanlı randevuların engellenmesini sağlayan iş kuralları.
- **PostgreSQL partial unique index:** Sadece aktif (`pending`, `confirmed`) randevuların çakışmasını önleyen kısmi benzersizlik indeksi.
- **Transaction management:** Servis katmanında bütüncül commit, rollback ve hata kurtarma akışı.
- **Concurrency protection:** Eş zamanlı isteklerin (race condition) veritabanı seviyesinde kontrol edilmesi.
- **OpenAPI documentation:** Tüm endpoint'leri, girdi-çıktı şemalarını ve hata durumlarını içeren otomatik OpenAPI dokümantasyonu.

---

## Technical Highlights
- **Layered Architecture:** Uygulama Router, Service, Repository ve Model katmanlarına ayrılarak SOLID prensiplerine uygun, sürdürülebilir ve gevşek bağlı (loosely coupled) bir yapıda tasarlanmıştır.
- **Repository Pattern:** Veri erişim mantığı soyutlanarak veritabanı sorguları ve persistence işlemleri izole edilmiştir.
- **Service Layer:** Randevu slotu doğrulama, tarih sınırları kontrolü ve işlem (transaction) yönetimi gibi iş kuralları servis katmanında toplanmıştır.
- **Dependency Injection:** FastAPI bağımlılık enjeksiyonu (`Depends`) kullanılarak asenkron veritabanı oturum yönetimi (`AsyncSession`) otomatik ve istek bazlı (request-scoped) yönetilmiştir.
- **Async SQLAlchemy:** `asyncpg` sürücüsüyle güçlendirilmiş asenkron SQLAlchemy 2.0 mimarisi kullanılarak yüksek paralel isteklerde I/O tıkanmalarının önüne geçilmiştir.
- **Pydantic v2:** Güçlü şema doğrulama, ekstra alan kısıtlamaları (`extra="forbid"`) ve optimize edilmiş JSON serileştirme kuralları uygulanmıştır.
- **PostgreSQL Partial Unique Index:** `status IN ('pending', 'confirmed')` filtresine sahip kısmi indeks sayesinde pasif randevuların slotları serbest bırakması ve aktiflerin korunması sağlanmıştır.
- **Race Condition Protection:** Eş zamanlı randevu isteklerinde veri tutarlılığı, yazılımsal ön kontrollerin yanı sıra veritabanı seviyesindeki benzersizlik kısıtları ile garanti altına alınmıştır.

---

## Testing Summary
Sprint 1 boyunca yazılan tüm testler gerçek PostgreSQL test veritabanında çalıştırılmış ve tam başarı elde edilmiştir.

**Toplam Test Sonuçları:**
- **124 Passed**
- **0 Failed**
- **0 Skipped**

**Test Tipleri:**
- **Unit Tests:** Servis ve slot üretici mantığının veritabanı bağımsız, izole birim testleri.
- **Integration Tests:** FastAPI istemcisi (`AsyncClient`) üzerinden uçtan uca HTTP çağrıları yapan entegrasyon testleri.
- **PostgreSQL Tests:** Gerçek geçici veritabanı şemalarında veri ekleme, silme, güncelleme ve partial index davranışlarının doğrulanması.
- **Concurrency Tests:** `asyncio.Barrier` yardımıyla aynı slot için aynı anda gönderilen iki paralel isteğin veri tutarlılığını nasıl koruduğunu doğrulayan eş zamanlılık testleri.
- **HTTP Endpoint Tests:** `400 Bad Request`, `404 Not Found`, `409 Conflict` ve `422 Unprocessable Entity` gibi HTTP yanıt kodlarının taranması.

---

## Challenges
- **AsyncPG "another operation is in progress" Hatası:** Asenkron testlerde tek bir veritabanı oturumunun (`AsyncSession`) eş zamanlı iki görev tarafından paylaşılmasından kaynaklanan bu hata, her HTTP isteğine bağımsız `AsyncClient` ve ayrı istek kapsamlı dependency enjeksiyonları sağlanarak tamamen çözülmüştür.
- **Docker Port Yapılandırması:** Geliştirme ortamındaki PostgreSQL host portu ile (`5433`) Docker ağ içi portunun (`5432`) yerel çakışmaları önlemek için doğru şekilde eşleştirilmesi ve `.env` üzerinden dinamik beslenmesi sağlanmıştır.
- **İşlem (Transaction) ve Rollback Yönetimi:** Benzersizlik ihlallerinde bozulan transaction durumunun (`PendingRollbackError` vb.) çözülmesi amacıyla servis katmanına asenkron `session.rollback()` çağrıları entegrasyonu sağlanarak oturum temizliği güvenceye alınmıştır.
- **Yarış Koşulu (Race Condition) Koruması:** Sadece kod içi kontrollerin eş zamanlı işlemlerde yetersiz kalması problemi, PostgreSQL partial unique index nihai güvencesiyle ve bunu `IntegrityError` içinden constraint adına göre süzüp `409`'a dönüştürerek çözülmüştür.
- **Saat Dilimi (Timezone) Yönetimi:** API ve sunucu saatlerinin yerel saat dilimine bağımlı kalmaması adına, proje standardı olarak `ZoneInfo("Europe/Istanbul")` sabitlenmiş, dışarıdan gelen veriler İstanbul dilimine normalize edilmiştir.

---

## Technical Debt
Sprint 2 ve sonraki aşamalara devredilen planlı teknik borçlar ve geliştirmeler:
- **Authentication:** Kullanıcı kimlik doğrulama altyapısının kurulması (Sprint 2 / Gün 7).
- **Authorization:** Rol bazlı (Esnaf / Müşteri) randevu erişim yetkilendirmesi (Sprint 2 / Gün 8-9).
- **Notifications:** Randevu durum değişikliklerinde gönderilecek e-posta/SMS bildirim servislerinin entegrasyonu.
- **Admin Dashboard:** Esnafların kendi slotlarını ve randevularını yönetebileceği yönetim paneli API'leri.
- **Logging Improvements:** Hata durumlarında detaylı izlenebilirlik için merkezi loglama mekanizmasının güçlendirilmesi.

---

## Sprint Metrics

| Metrik Başlığı | Değer / Durum |
| :--- | :--- |
| **Sprint Duration** | 6 Gün |
| **Completed Story Points (yaklaşık)** | 13 SP |
| **Features** | 15 Completed Features |
| **Endpoints** | 6 Endpoints |
| **Database Tables** | 2 Database Tables (business, appointment) |
| **Tests** | 124 Tests Passed |
| **Docker** | Yapılandırılmış ve Test Edilmiş |
| **Migration** | Alembic (Downgrade/Upgrade döngüsü aktif) |

---

## Sprint Result
SıraSende projesinin ilk sprint'i, belirlenen tüm kabul kriterlerini eksiksiz şekilde karşılayarak üstün bir başarıyla tamamlanmıştır. Backend mimarisinin asenkron temelleri, veritabanı kısıtları ve eş zamanlılık koruması son derece kararlı ve dayanıklı bir biçimde inşa edilmiştir. Yüksek test kapsama oranı ve otomatik göç mekanizmaları, sonraki sprint'lerde geliştirilecek olan esnaf yetkilendirme ve randevu yönetim modülleri için güvenli ve pürüzsüz bir zemin sunmaktadır.Sprint 1, planlanan tüm kullanıcı hikâyeleri ve teknik kabul kriterleri tamamlanarak zamanında teslim edilmiştir.

---

Prepared by: Nisa İrem Dilekçi 
Project: SıraSende  
Sprint: Sprint 1  
Status: Completed
