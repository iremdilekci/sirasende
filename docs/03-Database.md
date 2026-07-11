# Veritabanı Tasarımı

SıraSende, PostgreSQL ve SQLAlchemy 2.x typed declarative modellerini kullanır.
Birincil anahtarlar PostgreSQL UUID tipindedir. Bütün ana tablolarda timezone bilgili
`created_at` ve `updated_at` alanları bulunur.

## Tablolar

### `businesses`

- `id`: UUID, birincil anahtar
- `name`: işletme adı
- `slug`: URL uyumlu, benzersiz işletme tanımlayıcısı
- `description`, `phone`, `address`: isteğe bağlı iletişim ve açıklama alanları
- `working_start_time`, `working_end_time`: çalışma saatleri
- `slot_duration_minutes`: 30, 45 veya 60 dakika
- `is_active`: işletmenin kullanım durumu
- `created_at`, `updated_at`: timezone bilgili kayıt zamanları

`working_end_time`, `working_start_time` değerinden sonra olmalıdır.

### `admin_users`

- `id`: UUID, birincil anahtar
- `business_id`: `businesses.id` dış anahtarı
- `username`: benzersiz kullanıcı adı
- `email`: benzersiz e-posta adresi
- `password_hash`: Argon2 parola özeti
- `is_active`: kullanıcı durumu
- `created_at`, `updated_at`: timezone bilgili kayıt zamanları

Düz metin parola veritabanına kaydedilmez. İşletme silindiğinde ona bağlı esnaf
kullanıcıları da silinir.

### `appointments`

- `id`: UUID, birincil anahtar
- `business_id`: `businesses.id` dış anahtarı
- `customer_name`, `customer_phone`: zorunlu müşteri bilgileri
- `customer_note`: isteğe bağlı not
- `appointment_date`: randevu tarihi
- `start_time`, `end_time`: randevu saat aralığı
- `status`: PostgreSQL `appointment_status` enum değeri
- `created_at`, `updated_at`: timezone bilgili kayıt zamanları

`end_time`, `start_time` değerinden sonra olmalıdır. İşletme silindiğinde ona bağlı
randevular da silinir.

## İlişkiler

- Bir `Business`, birden fazla `Appointment` içerebilir.
- Bir `Business`, bir veya daha fazla `AdminUser` içerebilir.
- Dış anahtarlar `ON DELETE CASCADE` kullanır.

## Randevu durumları

- `pending`: yeni randevunun varsayılan durumu
- `confirmed`: esnaf tarafından onaylandı
- `cancelled`: iptal edildi
- `completed`: tamamlandı

Aktif randevu çakışmasını engelleyen partial unique index Gün 6 kapsamındadır ve bu
migration'a dahil edilmemiştir.

## Migration komutları

Proje kökünden Docker Compose ile:

```powershell
docker compose exec backend alembic upgrade head
docker compose exec backend alembic downgrade base
docker compose exec backend alembic upgrade head
```

Backend doğrudan yerel Python ortamında çalışıyorsa:

```powershell
Set-Location backend
alembic upgrade head
```

## Seed verisi

`.env` içinde gerçek ve güçlü bir `SEED_ADMIN_PASSWORD` tanımlandıktan sonra:

```powershell
docker compose exec backend python -m app.scripts.seed
```

Seed scripti `demo-kuafor` işletmesini ve örnek esnaf kullanıcısını yalnızca mevcut
değillerse oluşturur. Tekrar çalıştırılması kayıtları çoğaltmaz. Örnek `change_me`
parolası kabul edilmez.

## Önemli veritabanı kuralları

- Slot süresi yalnızca 30, 45 veya 60 olabilir.
- İşletme ve randevu bitiş saati başlangıç saatinden sonra olmalıdır.
- İşletme slug değeri benzersizdir.
- Esnaf kullanıcı adı ve e-posta adresi benzersizdir.
- Yeni randevular `pending` durumunda oluşturulur.
- Parolalar yalnızca güvenli özet biçiminde saklanır.
