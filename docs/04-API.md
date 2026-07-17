# SıraSende API Dokümantasyonu (04-API.md)

Bu doküman, SıraSende platformunun API uç noktalarını (endpoints) ve bu uç noktaların kullanım detaylarını içerir.

---

## Kimlik Doğrulama (Authentication)

Tüm korumalı yönetici (admin) uç noktalarına yapılacak isteklerde JWT access token kullanılmalıdır. Token, istemci tarafından HTTP isteklerinin başlığına (header) `Authorization: Bearer <token>` biçiminde eklenmelidir.

### 1. Giriş Yap ve Token Al (Login)
Yönetici kullanıcının kullanıcı adı veya e-posta ve parola bilgileriyle sisteme giriş yaparak JWT token almasını sağlar.

*   **Uç Nokta (URL):** `/api/v1/auth/login`
*   **Yöntem (Method):** `POST`
*   **İstek Gövdesi (Request Body - JSON):**
    ```json
    {
      "identifier": "demo_admin",
      "password": "ExamplePassword123!"
    }
    ```
    *   `identifier` (Zorunlu): Kullanıcı adı (`username`) ya da E-posta (`email`) değerini kabul eder. Başındaki ve sonundaki boşluklar otomatik olarak temizlenir (stripped).
    *   `password` (Zorunlu): Parola değeri. Boşluklar korunur.

*   **Başarılı Yanıt (HTTP 200 OK):**
    ```json
    {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "token_type": "bearer",
      "expires_in": 1800
    }
    ```
    *   `access_token`: Korumalı API'lere erişmek için kullanılacak JWT token.
    *   `token_type`: Token türü (her zaman `"bearer"`).
    *   `expires_in`: Token geçerlilik süresi (saniye cinsinden, varsayılan `1800` saniye / 30 dakika).

*   **Hata Yanıtları:**
    *   **HTTP 401 Unauthorized:** Kullanıcı bulunamazsa, şifre yanlışsa, hesap aktif değilse (`is_active = False`) veya çapraz identifier çakışması (belirsizliği) varsa bu hata döner. Kullanıcı tespiti (enumeration) riskine karşı tüm credential hata durumlarında aynı genel mesaj döndürülür:
        *   Yanıt Gövdesi: `{"detail": "Could not validate credentials"}`
        *   Yanıt Başlığı (Header): `WWW-Authenticate: Bearer`
    *   **HTTP 422 Unprocessable Entity:** İstek formatı geçersizse veya gerekli alanlar boş/sadece boşluktan oluşuyorsa döner.

---

### 2. Giriş Yapan Yönetici Bilgileri (/me)
Giriş yapmış olan aktif yöneticinin profil bilgilerini döndürür. Token ile korunmaktadır.

*   **Uç Nokta (URL):** `/api/v1/auth/me`
*   **Yöntem (Method):** `GET`
*   **İstek Başlığı (Request Header):**
    `Authorization: Bearer <access_token>` (ya da `Authorization: bearer <access_token>`)

*   **Başarılı Yanıt (HTTP 200 OK):**
    ```json
    {
      "id": "e63a1fa0-82be-4ba5-8025-a8647eb38a6a",
      "business_id": "06650a65-67e6-4ccd-97b9-ddd0a173f112",
      "username": "demo_admin",
      "email": "demo@example.com",
      "is_active": true
    }
    ```
    *   *Güvenlik:* Kullanıcının `password_hash` bilgisi yanıt gövdesinde kesinlikle yer almaz.

*   **Hata Yanıtları:**
    *   **HTTP 401 Unauthorized:** Token eksikse, süresi geçmişse, imza veya algoritma doğrulanamamışsa ya da kullanıcı pasif durumdaysa/silinmişse döner.
        *   Yanıt Gövdesi: `{"detail": "Could not validate credentials"}`
        *   Yanıt Başlığı (Header): `WWW-Authenticate: Bearer`

---

## JWT Claimleri

SıraSende JWT access token'ları aşağıdaki claimleri (iddiaları) içerir:
*   `sub` (Subject): Kimliği doğrulanmış olan AdminUser nesnesinin UUID'si.
*   `iat` (Issued At): Token'ın oluşturulduğu UTC zaman damgası (timestamp).
*   `exp` (Expiration Time): Token'ın geçerliliğini yitireceği UTC zaman damgası.
*   `type` (Token Type): Token'ın türü (her zaman `"access"` olarak imzalanır).

---

## Güvenlik Kararları

1.  **Argon2id Şifreleme:** Şifre hash'leme ve doğrulama işlemleri için CPU ve bellek odaklı en güvenli şifreleme algoritmalarından biri olan Argon2id (pwdlib sarmalayıcısı ile) kullanılır.
2.  **Timing Attack ve Kullanıcı Enumeration Önlemleri:**
    *   Bulunmayan ve belirsiz identifier durumlarında dummy Argon2 doğrulaması uygulanarak login akışındaki belirgin timing enumeration riski azaltılmıştır.
    *   Kullanıcı pasiflik kontrolü (`is_active`), şifre doğrulamasının hemen sonrasına bırakılarak zamanlama analiziyle aktif olmayan hesapların saptanması zorlaştırılmıştır.
3.  **Algoritma Sınırlandırması (Allowlist):** JWT imza çözme işleminde sadece settings içindeki imza algoritması (`HS256`) kabul edilir.
4.  **Zorunlu Claim Denetimleri:** JWT decode aşamasında `exp` ve `sub` claim'lerinin varlığı kütüphane seviyesinde zorunlu tutulmuştur.
5.  **Güçlü sub Validasyonu:** `sub` claim'inin sadece string olması değil, aynı zamanda geçerli bir `UUID` dizesi olması zorunlu tutulmuştur.
6.  **HTTPBearer auto_error=False Ayarı:** FastAPI'nin token eksikliğinde otomatik olarak `403 Forbidden` atmasını engellemek ve RFC 6750 standardına uygun `401 Unauthorized` & `WWW-Authenticate: Bearer` döndürmek amacıyla `auto_error=False` ayarlanmıştır.
7.  **Çapraz Identifier Çakışma Önlemi:** Bir e-posta adresi ile bir kullanıcı adının çakışması durumunda (`limit(2)` sonucunda) `AmbiguousIdentifierError` fırlatılır ve giriş işlemi ortak 401 hatasıyla sonlandırılır.
8.  **Aktiflik ve Silinme Kontrolü:** Geçerli bir token gönderilse bile dependency katmanında veritabanı sorgusuyla kullanıcının silinip silinmediği veya pasife alınıp alınmadığı her istekte anlık olarak doğrulanır.

---

## Katmanlar ve Sorumlulukları

*   `backend/app/schemas/auth.py`: İstek (`LoginRequest`) ve yanıt (`TokenResponse`, `AdminUserOut`) şemaları.
*   `backend/app/repositories/admin_user_repository.py`: Kullanıcı sorgulama veritabanı işlemleri.
*   `backend/app/services/auth_service.py`: Dummy Argon2 entegrasyonu ve giriş iş mantığı.
*   `backend/app/core/security.py`: Argon2id hash/verify ve JWT encode/decode işlemleri.
*   `backend/app/api/deps.py`: Token doğrulama bağımlılığı ve ortak `raise_credentials_exception` yardımı.
*   `backend/app/api/v1/auth.py`: `/login` ve `/me` API endpoint yönlendiricileri.

---

## Environment Değişkenleri

Sistem çalıştırılmadan önce `.env` dosyası içerisinde aşağıdaki değişkenler yapılandırılmalıdır:
*   `JWT_SECRET_KEY`: JWT imzalamada kullanılacak gizli anahtar.
    *   *Önemli:* Üretim (production) ortamında en az 32 karakter uzunluğunda, karmaşık ve rastgele bir değer seçilmelidir. Güvenlik nedeniyle asla kaynak kod deposuna (repository) eklenmemelidir.
*   `JWT_ALGORITHM`: Kullanılacak algoritma (Örn: `HS256`).
*   `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`: Token ömrü (dakika cinsinden, örn: `30`).

