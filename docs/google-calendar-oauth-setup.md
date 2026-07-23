# Google Calendar OAuth Kurulum Kılavuzu

Bu doküman, SıraSende uygulamasında esnaf kullanıcılarının Google Takvim hesaplarını bağlayabilmesi için gerekli olan Google OAuth 2.0 yapılandırmasını açıklamaktadır.

## 1. Google Cloud Console Proje Kurulumu

1. [Google Cloud Console](https://console.cloud.google.com/) adresine gidin.
2. Yeni bir proje oluşturun veya mevcut projenizi seçin.
3. Sol menüden **APIs & Services** > **Enabled APIs & Services** sayfasına gidin.
4. **+ ENABLE APIS AND SERVICES** butonuna tıklayın.
5. Arama çubuğuna **Google Calendar API** yazıp aratın, API sayfasına giderek **Enable** butonuna tıklayın.

## 2. OAuth Consent Screen (Yetki Ekranı) Yapılandırması

1. Sol menüden **APIs & Services** > **OAuth consent screen** sayfasına gidin.
2. User Type olarak **External** seçip **Create** deyin.
3. Uygulama bilgilerini girin:
   - **App name**: SıraSende
   - **User support email**: Kendi e-postanızı seçin.
   - **Developer contact information**: E-postanızı girin.
4. **Scopes (İzinler)** adımına geçin ve aşağıdaki scope'ları ekleyin:
   - `.../auth/calendar.events` (Google Takvim etkinliklerini okuma ve yazma izni)
   - `.../auth/userinfo.email` (Kullanıcının e-posta adresini görme izni)
   - `openid`
5. **Test users** adımında yetkilendirme yapacak test Google hesaplarını (kendi hesaplarınızı) ekleyin.

## 3. Kimlik Bilgilerinin (Credentials) Oluşturulması

1. Sol menüden **APIs & Services** > **Credentials** sayfasına gidin.
2. **+ CREATE CREDENTIALS** butonuna tıklayıp **OAuth client ID** seçeneğini seçin.
3. **Application type** olarak **Web application** seçin (Backend yönlendirmeyi üstlendiği için Web application seçilmelidir).
4. **Name** kısmına "SıraSende Backend Client" gibi açıklayıcı bir isim verin.
5. **Authorized redirect URIs** alanına backend callback adresini ekleyin:
   - Yerel ortam için: `http://localhost:8000/api/v1/admin/google-calendar/callback`
   - Canlı ortam için: `https://<api-domain>/api/v1/admin/google-calendar/callback`
6. **Create** butonuna basarak **Client ID** ve **Client Secret** değerlerini oluşturun. Bu değerleri güvenli bir yerde saklayın.

## 4. Ortam Değişkenlerinin (Environment Variables) Yapılandırılması

`.env` dosyanıza aşağıdaki değişkenleri ekleyin (asla commit etmeyin):

```env
# Google OAuth 2.0 Credentials
GOOGLE_CLIENT_ID="<your-google-client-id>"
GOOGLE_CLIENT_SECRET="<your-google-client-secret>"
GOOGLE_OAUTH_REDIRECT_URI="http://localhost:8000/api/v1/admin/google-calendar/callback"

# Token Encryption (Hassas Google refresh token'ları AES-GCM-256 ile şifrelenir)
# 32 baytlık url-safe base64 formatında bir anahtar olmalıdır.
# Üretmek için python console: cryptography.fernet.Fernet.generate_key().decode()
GOOGLE_TOKEN_ENCRYPTION_KEY="<32-byte-urlsafe-base64-key>"
```

## 5. Güvenlik ve Depolama Detayları

- **State Güvenliği**: CSRF saldırılarını önlemek amacıyla her OAuth isteği için kriptografik olarak güvenli 32 karakterlik random bir state token üretilir. Bu state'in SHA-256 özeti (`state_hash`) veritabanında (`google_oauth_states`) 10 dakika geçerlilik süresi ve ilişkili `business_id` ile saklanır. Callback sırasında state tek kullanımlık olarak tüketilir, süresi dolan veya ikinci kez kullanılan state'ler kesinlikle reddedilir.
- **Refresh Token Depolama**: Kullanıcının çevrimdışı erişim izniyle elde edilen `refresh_token`, veritabanında ham metin olarak tutulmaz. `GOOGLE_TOKEN_ENCRYPTION_KEY` kullanılarak donanımsal düzeyde AES-GCM-256 şifrelemesiyle veritabanına kaydedilir.
- **Bağlantı Kesme (Disconnect)**: Bağlantı kesildiğinde işletmeye ait bağlantı kaydı DB'den silinir ve Google API'sine (`/revoke` endpoint) istek atılarak token geçersiz kılınır. Disconnect işlemi idempotenttir (zaten bağlantı yoksa hata vermeden başarılı mesajı döner).
