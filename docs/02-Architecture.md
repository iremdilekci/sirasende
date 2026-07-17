# SıraSende Sistem Mimarisi (02-Architecture.md)

SıraSende platformunun temel yazılım mimarisi; asenkron RESTful backend, ilişkisel veritabanı katmanı ve mobil istemci arasında gevşek bağlı (loosely coupled), ölçeklenebilir ve yüksek performanslı bir yapıda tasarlanmıştır.

---

## 1. Genel Sistem Mimarisi

Sistem, istemci ve sunucu katmanlarının net bir şekilde ayrıldığı (Separation of Concerns) ve veri tutarlılığının veritabanı seviyesinde de korunduğu çok katmanlı (Multi-layered) bir mimariye sahiptir.

```mermaid
graph TD
    subgraph Client Layer
        FlutterApp[Flutter Mobil Uygulaması]
    end

    subgraph API & Route Layer
        FastAPI[FastAPI Router / Endpoint]
        Deps[Dependency Injection / deps.py]
    end

    subgraph Business Logic Layer
        Service[Service Katmanı / appointment_service.py]
        SlotService[Slot Servisi / slot_service.py]
    end

    subgraph Data Access Layer
        Repo[Repository Katmanı / appointment_repository.py]
        Models[SQLAlchemy Modelleri / Models]
    end

    subgraph Database Layer
        PostgreSQL[(PostgreSQL Veritabanı)]
    end

    FlutterApp -->|HTTP REST Requests| FastAPI
    FastAPI -->|dependency injection| Deps
    FastAPI -->|calls services| Service
    Service -->|calls slot algorithms| SlotService
    Service -->|calls persistence| Repo
    Repo -->|ORM operations| Models
    Models -->|asyncpg driver| PostgreSQL
```

---

## 2. Mimari Tasarım Desenleri (Design Patterns)

Backend katmanında veri erişimi, iş mantığı ve sunum katmanlarının temiz bir şekilde ayrıştırılması amacıyla aşağıdaki desenler uygulanmıştır:

### Katmanlı Mimari (Layered Architecture)
Uygulama, bağımlılıkların yalnızca yukarıdan aşağıya doğru aktığı yapısal katmanlardan oluşur:
1.  **Presentation (Router) Katmanı:** FastAPI uç noktalarını (`api/v1/businesses.py`) içerir. Gelen HTTP isteklerini karşılar, Pydantic şemaları ile istek gövdesini doğrular, ilgili servis fonksiyonunu çağırır ve domain hatalarını uygun HTTP durum kodlarına (`201`, `400`, `404`, `409`) dönüştürür.
2.  **Service (Business Logic) Katmanı:** İş mantığının (`app/services/`) işletildiği yerdir. Zaman slotlarının doğrulanması, randevu çakışmalarının önlenmesi ve işlemlerin (transaction) yönetimi burada yapılır.
3.  **Repository (Data Access) Katmanı:** Doğrudan veritabanı sorgularının (`app/repositories/`) yazıldığı katmandır. SQL / SQLAlchemy sorgularını servislerden izole eder.
4.  **Database Models Katmanı:** Veritabanındaki tabloları temsil eden SQLAlchemy ORM nesneleridir.

### Repository Tasarım Deseni
Veri tabanından veri çekme ve veritabanına veri yazma işlemleri asenkron sorgularla repository sınıfları/fonksiyonları içinde yapılır.
*   **Kural:** Repository fonksiyonları asenkron oturum (`AsyncSession`) üzerinde yalnızca veri çekme (`select`), ekleme (`add`) ve senkronize etme (`flush`) işlemlerini yürütür. Kendi başlarına `commit`, `rollback` yapmaz veya domain hatası fırlatmaz.
*   **Amaç:** İş mantığı ile veritabanı sorgularını ayırarak test edilebilirliği artırmak ve veritabanı bağımlılığını kolayca mock'layabilmektir.

### Servis Katmanı & İşlem (Transaction) Sorumluluğu
Veritabanı işlemlerinin (transaction) atomikliği ve veri bütünlüğü servis katmanında yönetilir.
*   **Kural:** `session.commit()` ve hata durumunda `session.rollback()` asenkron çağrıları yalnızca servis katmanında tetiklenir.
*   **Hata Dönüşümü:** Veritabanından fırlatılan ham kısıt ihlali hataları (`IntegrityError`), servis katmanında yakalanarak temiz domain hatalarına (`AppointmentConflictError`) dönüştürülür.

---

## 3. Dinamik Slot Üretim ve Randevu Akışı

Randevu alma süreçleri tamamen asenkron slot hesaplamaları ve veritabanı kısıt doğrulamaları üzerinden ilerler.

```mermaid
sequenceDiagram
    autonumber
    actor Client as Mobil İstemci
    participant Router as API Router
    participant Service as Service Katmanı
    participant Repo as Repository Katmanı
    participant DB as PostgreSQL

    Client->>Router: POST /api/v1/businesses/{slug}/appointments
    note over Router: İstek Pydantic ile validate edilir.<br/>(extra="forbid", customer_phone min 5)
    Router->>Repo: get_active_business_by_slug()
    Repo->>DB: SELECT business (is_active=True)
    DB-->>Repo: business data
    
    note over Router: İşletme aktif değilse 404 dönülür.
    
    Router->>Service: create_appointment(session, business, payload)
    note over Service: build_pending_appointment() çağrılır.<br/>(Tarih ve slot sınırları doğrulanır.)
    
    Service->>Repo: get_active_appointment_for_slot()
    Repo->>DB: SELECT active appointments (pending, confirmed)
    DB-->>Repo: appointments
    
    alt Slot Ön Kontrolü: Dolu
        Service-->>Router: raise AppointmentConflictError
        Router-->>Client: HTTP 409 Conflict
    else Slot Ön Kontrolü: Müsait
        Service->>Repo: add_appointment() (session.add & session.flush)
        Service->>DB: session.commit()
        alt Eş Zamanlı Yarış Koşulu (Race Condition) Oluştuysa
            DB-->>Service: Raise IntegrityError (Constraint: uq_appointments_active_slot)
            Service->>DB: session.rollback()
            Service-->>Router: raise AppointmentConflictError
            Router-->>Client: HTTP 409 Conflict
        else Kayıt Başarılıysa
            Service->>DB: session.refresh(appointment)
            Service-->>Router: Appointment ORM Model
            Router-->>Client: HTTP 201 Created (AppointmentOut)
        end
    end
```

---

## 4. Eş Zamanlılık ve Yarış Koşulu Koruması (Concurrency)

SıraSende platformu, aynı zaman dilimine birden fazla aktif randevu oluşturulmasını önlemek için **iyimser kilitleme ve veritabanı seviyesinde kısmi benzersizlik indeksi** (PostgreSQL Partial Unique Index) stratejilerini bir arada kullanır.

### Çift Katmanlı Koruma
1.  **Yazılımsal Ön Kontrol:** Randevu kaydı yapılmadan önce repository seviyesinde `get_active_appointment_for_slot` sorgusu koşturulur. Slot dolu ise işlem hızlıca `409` hatasıyla kesilir.
2.  **Veritabanı Seviyesinde Nihai Güvence:** Ön kontrol ile kayıt (commit) anı arasında geçen sürede başka bir istemcinin aynı slotu alması durumunda (Race Condition), PostgreSQL partial unique index devreye girerek ikinci commit işlemini engeller.

### Kısmi Benzersizlik İndeksi (Partial Unique Index)
İptal edilmiş (`cancelled`) veya tamamlanmış (`completed`) eski randevuların aynı slot için tekrar randevu alınmasını engellememesi amacıyla, benzersizlik kısıtı sadece aktif randevulara uygulanır.

*   **İndeks Adı:** `uq_appointments_active_slot`
*   **İndeks Tanımı (SQL):**
    ```sql
    CREATE UNIQUE INDEX uq_appointments_active_slot 
    ON appointments (business_id, appointment_date, start_time) 
    WHERE status IN ('pending', 'confirmed');
    ```

---

## 5. Altyapı ve Konteynerleşme

Uygulama, yerel geliştirme ve canlıya alma ortamlarının eşitliğini sağlamak için Docker Compose mimarisi üzerine kurulmuştur:

*   **`db` Servisi:** PostgreSQL 16 veritabanını barındırır. Port çakışmalarını önlemek amacıyla host tarafında `5433` portuna map edilmiştir. Verilerin kalıcı olması için `postgres_data` volume'ü tanımlıdır.
*   **`backend` Servisi:** FastAPI uygulamasını barındırır. Docker dosya paylaşımları (bind mounts) sayesinde kod değişiklikleri canlı olarak yansıtılır (reload modu). `db` servisinin sağlıklı (`service_healthy`) duruma gelmesine bağımlıdır.
