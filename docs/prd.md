# SıraSende – Ürün Gereksinimleri Dokümanı (PRD)

## 1. Proje Genel Bakışı & Hedefler

**SıraSende**, küçük ve orta ölçekli hizmet veren işletmelerin (kuaförler, berberler, güzellik merkezleri vb.) randevu yönetim süreçlerini dijitalleştirmek amacıyla geliştirilen **mobil öncelikli** bir randevu sistemidir.

### Temel Hedefler
*   **Hızlı ve Üyeliksiz Erişim:** Müşterilerin karmaşık kayıt ve üyelik süreçleriyle uğraşmadan, saniyeler içinde müsait gün/saati seçerek randevu alabilmesini sağlamak.
*   **Kolay Esnaf Yönetimi:** İşletme sahibinin (esnafın) gelen randevuları tek bir mobil ekran üzerinden kolayca yönetebilmesini (onaylama, iptal etme, tamamlama) sağlamak.
*   **Çakışmasız Slot Yönetimi:** Aynı tarih ve saat dilimi için birden fazla aktif randevu oluşturulmasını hem uygulama hem de veritabanı düzeyinde kesin olarak engellemek.

---

## 2. Kullanıcı Rolleri & Personalar

### 2.1. Müşteri (Üyeliksiz Kullanıcı)
*   **Tanım:** İşletmeden randevu almak isteyen ve sisteme üye olmayan son kullanıcıdır.
*   **Temel İhtiyaçlar:**
    *   İşletmelerin detaylarını (çalışma saatleri, iletişim) ve müsaitlik durumunu hızlıca görmek.
    *   Tarih seçip dinamik olarak oluşturulan boş saat dilimlerini (slotları) görüntülemek.
    *   Sadece Ad, Telefon ve isteğe bağlı bir Not yazarak anında randevu oluşturabilmek.

### 2.2. Esnaf / İşletme Sahibi (Yetkilendirilmiş Kullanıcı)
*   **Tanım:** Randevu takvimini kontrol eden ve hizmet sunan işletme yöneticisidir.
*   **Temel İhtiyaçlar:**
    *   Kullanıcı adı/e-posta ve şifresiyle güvenli bir şekilde giriş yapabilmek.
    *   Gelen randevu isteklerini tarih ve saate göre sıralı bir şekilde listelemek.
    *   Randevuları onaylamak, iptal etmek veya tamamlandı olarak işaretlemek.
    *   Güvenli bir şekilde çıkış yapabilmek.

---

## 3. Platform & Dağıtım Hedefleri

*   **Mobil Uygulama (Flutter):**
    *   Hem **Android** hem de **iOS** platformlarında çalışacak ortak bir kod tabanıyla geliştirilecektir.
    *   Ana geliştirme ve test önceliği Android platformundadır. iOS derlemesi ve ince ayarları platform kısıtlarına uygun şekilde yürütülecektir.
*   **Backend REST API (FastAPI):**
    *   Geliştirilecek API, istemci uygulamadan tamamen bağımsız bir mikroservis yapısında tasarlanacaktır.
    *   Bu bağımsız yapı sayesinde, mobil uygulama tamamlandıktan sonra eklenecek olan React tabanlı müşteri web arayüzü de aynı API'yi kullanabilecektir.
*   **Monorepo Yapısı:**
    *   Tüm alt projeler (backend, mobile, web, docs) tek bir Git repository'si (`sirasende/`) içinde barındırılacaktır.

---

## 4. MVP Kapsamı (Minimum Uygulanabilir Ürün)

### 4.1. Müşteri Özellikleri
1.  **Rol Seçimi:** Uygulama açılışında müşteri veya esnaf rolünü seçebilme.
2.  **İşletme Listeleme & Detay:** Sistemdeki kayıtlı işletmeleri listeleme ve seçilen işletmenin çalışma saatleri, açıklaması gibi detayları görüntüleme.
3.  **Tarih Seçimi:** Randevu alınmak istenen tarihi takvim üzerinden seçme.
4.  **Dinamik Slot Görünümü:** Seçilen tarihe ve işletmenin slot süresine göre (30, 45, 60 dk) üretilen zaman dilimlerinin durumunu (Boş, Dolu, Geçmiş Saat) canlı görme.
5.  **Randevu Formu:** Ad, telefon ve not alanlarını doldurarak randevu talebi gönderme.
6.  **Randevu Başarı/Hata Ekranları:** Randevu alındığında onay ekranı görme; slotun başka biri tarafından o esnada rezerve edilmesi durumunda hata mesajı alma.

### 4.2. Esnaf Özellikleri
1.  **JWT Giriş Sistemi:** Benzersiz kullanıcı adı/e-posta ve şifre ile sisteme güvenli giriş yapabilme.
2.  **JWT Tabanlı Oturum Yönetimi:** Güvenli yerel depolama (Flutter Secure Storage) kullanarak oturumun korunması.
3.  **Randevu Listeleme:** İşletmesine gelen tüm randevuları kronolojik sırayla listeleme.
4.  **Randevu Durum Güncelleme:** Randevunun durumunu onaylandı, iptal edildi veya tamamlandı şeklinde güncelleyebilme.
5.  **Çıkış (Logout):** Oturumu sonlandırma.

### 4.3. Backend Özellikleri
1.  **İşletme Yönetimi API'leri:** İşletmeleri listeleme ve slug parametresiyle detay getirme.
2.  **Dinamik Slot Motoru:** Çalışma saatleri sınırları içinde slot hesaplama ve geçmiş zamanları otomatik pasife alma.
3.  **Çakışma Önleme Sistemi:** Eş zamanlı randevu isteklerinde çakışmayı önlemek amacıyla veritabanı seviyesinde işlem (transaction) yönetimi ve kısmi benzersiz indeks (partial unique index).
4.  **JWT Güvenlik Altyapısı:** Korumalı admin uç noktaları için JWT doğrulama middleware/bağımlılık yapısı.

---

## 5. Kritik İş & Veritabanı Kuralları

> [!IMPORTANT]
> Projenin kararlılığı ve veri tutarlılığı açısından aşağıdaki kurallar hem uygulama kodunda hem de PostgreSQL seviyesinde zorunlu kılınmıştır.

### 5.1. Slot Kuralları
*   İşletmenin slot süresi yalnızca **30, 45 veya 60 dakika** olabilir.
*   Mesai bitiş saati başlangıç saatinden büyük olmalıdır (`working_end_time > working_start_time`).
*   Bitiş saatini aşan veya mesai saatleri dışına taşan slotlar üretilmez.

### 5.2. Geçmiş ve Zaman Kontrolleri
*   Geçmiş bir güne randevu alınamaz.
*   Bugün için randevu alınırken, şu anki saatten daha önceki zaman dilimleri (geçmiş slotlar) müşteriye kapalı ve seçilemez gösterilir.

### 5.3. Doluluk ve Çakışma Yönetimi
*   Aşağıdaki statüdeki randevular slotu **dolu** kabul ettirir:
    *   `pending` (Onay bekliyor)
    *   `confirmed` (Onaylandı)
*   Aşağıdaki statüdeki randevular slotu **boş** bırakır:
    *   `cancelled` (İptal edildi)
    *   `completed` (Tamamlandı)
*   Aynı **İşletme, Tarih ve Başlangıç Saati** kombinasyonuna sahip ikinci bir aktif randevu (`pending` veya `confirmed`) veritabanına eklenemez. PostgreSQL üzerinde kısmi benzersiz indeks (`Partial Unique Index`) bu kuralı güvenceye alır.

### 5.4. Randevu Durum Geçiş Diyagramı
Randevu durumları sadece belirli kurallara göre değiştirilebilir:
*   `pending` ➔ `confirmed` (Esnaf onayladı)
*   `pending` ➔ `cancelled` (Esnaf reddetti/iptal etti)
*   `confirmed` ➔ `cancelled` (Onaylı randevu iptal edildi)
*   `confirmed` ➔ `completed` (Hizmet tamamlandı)

---

## 6. Teknik Gereksinimler & Teknoloji Yığını

### Backend
*   **Dil ve Framework:** Python 3.11+, FastAPI
*   **Veritabanı ve ORM:** PostgreSQL 16, SQLAlchemy 2.x (Typed Declarative Modeller)
*   **Migration:** Alembic
*   **Kimlik Doğrulama:** JWT (Argon2 parola özetleme algoritması ile)
*   **Test:** Pytest & Pytest-asyncio
*   **Konteynerleştirme:** Docker & Docker Compose

### Mobil (Müşteri ve Esnaf Ortak)
*   **Framework:** Flutter & Dart
*   **Durum Yönetimi:** Riverpod
*   **Yönlendirme:** GoRouter
*   **HTTP İstemcisi:** Dio
*   **Güvenli Depolama:** Flutter Secure Storage
*   **Yerelleştirme:** Intl (Tarih ve saat biçimlendirmeleri için)

---

## 7. MVP Dışı (Gelecek Faz) Özellikler
İlk sürümde yer almayacak ve MVP kapsamı dışında tutulan başlıklar:
*   Müşteri üyelik ve profil ekranları.
*   Çoklu çalışan veya uzman yönetimi.
*   Çoklu şube desteği.
*   Online ödeme entegrasyonu.
*   SMS veya WhatsApp bildirimleri.
*   Push bildirimleri.
*   Randevu saati düzenleme (Müşterinin veya esnafın tarihi kaydırması).

---

## 8. Bonus Özellikler (MVP Sonrası)

### 8.1. Google Calendar Entegrasyonu
Esnafın onayladığı randevuların otomatik olarak Google Takvim'ine işlenmesi.
*   Google OAuth 2.0 ile yetkilendirme akışı.
*   Esnafın Google Refresh Token'ının güvenli saklanması.
*   Randevu durum güncellemelerinde Google Takvim senkronizasyonu.

### 8.2. React Müşteri Web Arayüzü
Müşterilerin mobil uygulama indirmeden web tarayıcısı üzerinden randevu alabilmesini sağlayan hafif web arayüzü.
*   React, TypeScript ve Tailwind CSS.
*   Yalnızca müşteri akışını (İşletme listesi, slot seçimi, randevu formu) içerir. Admin/Esnaf paneli web kapsamında yer almaz.
