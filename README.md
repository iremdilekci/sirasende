# 🚀 SıraSende

SıraSende, kuaför, berber, güzellik merkezi ve benzeri işletmeler için geliştirilen modern bir çevrim içi randevu yönetim platformudur.

Proje; FastAPI, PostgreSQL ve Flutter tabanlı, ölçeklenebilir bir mimariyle geliştirilmektedir.

> **Project Status:** 🚧 Active Development (Sprint 1 Completed)

---

# ✨ Features

## Sprint 1

- ✅ FastAPI Backend
- ✅ PostgreSQL Integration
- ✅ SQLAlchemy 2.x Async ORM
- ✅ Alembic Migration System
- ✅ Docker Development Environment
- ✅ Health Check Endpoints
- ✅ Business Listing API
- ✅ Business Detail API
- ✅ Dynamic Slot Generation
- ✅ Slot Availability API
- ✅ Appointment Creation API
- ✅ Race Condition Protection
- ✅ PostgreSQL Partial Unique Index
- ✅ OpenAPI Documentation
- ✅ Unit & Integration Test Suite

---

# 🏗 Architecture

```
Flutter Mobile
        │
        ▼
FastAPI REST API
        │
        ▼
 Service Layer
        │
        ▼
 Repository Layer
        │
        ▼
 PostgreSQL
```

---

# 🛠 Tech Stack

### Backend

- Python 3.13
- FastAPI
- SQLAlchemy 2.x
- asyncpg
- Alembic
- PostgreSQL
- Pydantic v2

### Infrastructure

- Docker
- Docker Compose

### Testing

- Pytest
- HTTPX
- AsyncIO

### Mobile (Planned)

- Flutter

---

# 📂 Project Structure

```
backend/
│
├── app/
│   ├── api/
│   ├── core/
│   ├── models/
│   ├── repositories/
│   ├── schemas/
│   ├── services/
│   └── scripts/
│
├── alembic/
├── tests/
│
docs/
```

---

# 📊 Sprint Progress

| Sprint | Status |
|----------|--------|
| Sprint 1 | ✅ Completed |
| Sprint 2 | 🔄 Planned |
| Sprint 3 | ⏳ Planned |
| Sprint 4 | ⏳ Planned |

---

# 🧪 Test Status

Current Result

```
124 Passed
0 Failed
0 Skipped
```

Test Categories

- Unit Tests
- Integration Tests
- PostgreSQL Tests
- HTTP Endpoint Tests
- Concurrency Tests

---

# 🔐 Concurrency Protection

SıraSende aynı zaman dilimine birden fazla randevu oluşturulmasını PostgreSQL Partial Unique Index kullanarak engeller.

```
pending
confirmed
```

durumundaki kayıtlar aynı slotu paylaşamaz.

Race condition senaryoları gerçek PostgreSQL üzerinde test edilmiştir.

---

# 📖 API

### Business

```
GET /api/v1/businesses
```

```
GET /api/v1/businesses/{slug}
```

### Slots

```
GET /api/v1/businesses/{slug}/slots
```

### Appointments

```
POST /api/v1/businesses/{slug}/appointments
```

OpenAPI

```
http://localhost:8000/docs
```

---

# 🚀 Local Development

```bash
git clone https://github.com/iremdilekci/sirasende.git

cd sirasende

docker compose up -d

cd backend

alembic upgrade head

python -m app.scripts.seed
```

Run Tests

```bash
pytest
```

---

# 📅 Roadmap

## Sprint 2

- JWT Authentication
- Authorization
- Customer Accounts
- Admin APIs

## Sprint 3

- Flutter Mobile App
- Booking Flow
- Business Dashboard

## Sprint 4

- Notifications
- Analytics
- Reporting

---

# 👩💻 Author

**İrem Dilekçi**

Software Engineering Student

---

# 📄 License

This project is developed for educational and portfolio purposes.
