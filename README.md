# SıraSende

Mobil öncelikli randevu yönetim sistemi.

## Teknolojiler

- Flutter
- FastAPI
- PostgreSQL
- Docker

## Repository yapısı

```text
backend/
mobile/
web/
docs/
```

## Yerel geliştirme kurulumu

1. `.env.example` dosyasını `.env` adıyla kopyalayın.
2. `.env` içindeki örnek parolayı güçlü ve yalnızca yerelde kullanılan bir parolayla değiştirin.
3. Servisleri başlatın:

```powershell
docker compose up --build -d
```

Uygulama sağlık kontrolleri:

```text
http://localhost:8000/health
http://localhost:8000/health/database
```

Yerel Windows ortamında backend doğrudan çalıştırılırsa `POSTGRES_HOST=localhost`
olmalıdır. Docker Compose, backend konteyneri için bu değeri otomatik olarak `db`
şeklinde değiştirir.

## PostgreSQL parola hatasını giderme

PostgreSQL ilk başlatıldığında kullanıcı ve parola bilgilerini kalıcı Docker volume'una
yazar. Daha sonra yalnızca `.env` dosyasındaki parolayı değiştirmek mevcut veritabanı
kullanıcısının parolasını değiştirmez. Henüz korunması gereken veri yoksa geliştirme
veritabanını yeniden oluşturun:

```powershell
docker compose down -v
docker compose up --build -d
```

`down -v` komutu geliştirme veritabanındaki tüm verileri siler.

## Testler

Backend bağımlılıklarını geliştirme grubu ile kurduktan sonra:

```powershell
python -m pip install -e ".\backend[dev]"
python -m pytest .\backend\tests
```

## Güvenlik

Gerçek `.env`, `.git` ve `backend/.venv` klasörlerini ZIP arşivlerine eklemeyin.
`.env` içinde bulunan bir parola daha önce paylaşılmışsa parolayı değiştirin.
