# SıraSende – Proje Genel Bakış

## Proje Adı

SıraSende

## Proje Tanımı

SıraSende, müşterilerin üyelik oluşturmadan işletmelerden randevu almasını sağlayan mobil öncelikli bir randevu yönetim uygulamasıdır.

İşletme sahipleri sisteme giriş yaparak gelen randevuları görüntüleyebilir, onaylayabilir, iptal edebilir veya tamamlandı olarak işaretleyebilir.

## Projenin Amacı

Projenin amacı, küçük ve orta ölçekli işletmeler için sade, hızlı ve güvenli bir randevu sistemi geliştirmektir.

Sistem aşağıdaki temel sorunları çözmeyi hedefler:

- Telefonla randevu alma zorunluluğunu azaltmak
- Aynı saat için birden fazla randevu oluşmasını engellemek
- İşletme sahibinin randevuları tek ekrandan yönetmesini sağlamak
- Müşterinin üyelik oluşturmadan hızlı şekilde randevu alabilmesini sağlamak

## Hedef Kullanıcılar

### Müşteri

- İşletmeleri görüntüler
- Uygun tarih ve saatleri seçer
- Ad, telefon ve not bilgilerini girer
- Randevu oluşturur

### İşletme Sahibi

- Kullanıcı adı veya e-posta ve şifreyle giriş yapar
- Gelen randevuları görüntüler
- Randevuları onaylar
- Randevuları iptal eder
- Randevuları tamamlandı olarak işaretler

## Platformlar

Ana uygulama Flutter ile geliştirilecektir.

Desteklenmesi hedeflenen platformlar:

- Android
- iOS

Ana geliştirme ve test işlemleri Android üzerinde yapılacaktır.

Backend bağımsız bir REST API olarak geliştirileceği için ileride React tabanlı bir web arayüzü de aynı API’yi kullanabilecektir.

## Ana Teknolojiler

### Backend

- Python
- FastAPI
- SQLAlchemy
- PostgreSQL
- Alembic
- JWT
- Pytest
- Docker
- Docker Compose

### Mobil Uygulama

- Flutter
- Dart
- Riverpod
- GoRouter
- Dio
- Flutter Secure Storage

### Bonus Web Uygulaması

- React
- TypeScript
- Tailwind CSS

## Temel Özellikler

- İşletme listeleme
- İşletme detaylarını görüntüleme
- Tarih seçme
- Dinamik randevu saatleri oluşturma
- Dolu ve boş saatleri gösterme
- Randevu oluşturma
- Aynı saat için ikinci randevuyu engelleme
- İşletme sahibi giriş sistemi
- Randevu durum yönetimi

## Bonus Özellikler

Ana mobil MVP tamamlandıktan sonra zaman kalırsa:

- Google Calendar entegrasyonu
- React tabanlı müşteri web arayüzü

## Geliştirme Yaklaşımı

Proje mobil öncelikli geliştirilecektir.

Geliştirme sırası:

1. Backend ve veritabanı
2. Randevu ve slot sistemi
3. İşletme sahibi giriş sistemi
4. Flutter müşteri ekranları
5. Flutter işletme sahibi ekranları
6. Test ve hata düzeltme
7. Google Calendar entegrasyonu
8. Web arayüzü

## Başarı Kriteri

Proje aşağıdaki ana akış çalıştığında başarılı kabul edilecektir:

1. Müşteri işletmeleri görüntüler.
2. İşletme seçer.
3. Tarih ve uygun saat seçer.
4. Randevu oluşturur.
5. Aynı saat tekrar rezerve edilemez.
6. İşletme sahibi giriş yapar.
7. Gelen randevuyu görüntüler.
8. Randevunun durumunu günceller.
