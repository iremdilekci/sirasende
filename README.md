<div align="center">

# 🚀 SıraSende

### Modern Appointment & Queue Management Platform

A mobile-first appointment and queue management system developed with **Flutter** and **FastAPI**.

<img src="mobile/assets/images/sirasende.png" width="180"/>

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-Latest-009688?logo=fastapi)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)
![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-5C6BC0)
![License](https://img.shields.io/badge/Status-Active-success)

</div>

---

# 📖 About

**SıraSende** is a mobile-first appointment management platform developed for small businesses such as beauty salons, barbers, clinics and similar service providers.

Customers can easily browse businesses, view available appointment slots and create appointments, while business owners manage appointments through a dedicated admin panel.

The system has been designed using **Clean Architecture**, secure authentication and modern software engineering practices.

---

# ✨ Features

## 👤 Customer

- Browse registered businesses
- View business details
- View working hours
- Automatic available slot generation
- Book appointments
- Conflict-safe appointment booking
- Appointment validation
- Responsive mobile interface

---

## 🏪 Merchant

- Merchant registration
- Secure authentication (JWT)
- Profile management
- Business information editing
- Working hours management
- Appointment management
- Dashboard statistics
- Appointment status updates
- Google Calendar integration

---

## 📅 Google Calendar Integration

- OAuth2 authentication
- Connect / Disconnect calendar
- Automatic calendar event creation
- Duplicate event prevention
- Safe callback handling
- Deep Link support

---

# 🏗️ Architecture

The project follows **Clean Architecture** principles.

```
Presentation
      │
      ▼
Application / Providers
      │
      ▼
Repository
      │
      ▼
Remote Data Source
      │
      ▼
FastAPI Backend
      │
      ▼
PostgreSQL
```

Backend also follows a layered architecture:

```
API
│
├── Services
├── Repositories
├── Schemas
├── Models
├── Core
└── Database
```

---

# 🛠 Tech Stack

## Mobile

- Flutter
- Dart
- Riverpod
- GoRouter
- Dio

## Backend

- FastAPI
- SQLAlchemy Async
- PostgreSQL
- Alembic
- Pydantic v2
- JWT Authentication

## DevOps

- Docker
- Docker Compose

## Testing

### Backend

- Pytest

### Mobile

- Flutter Test
- Widget Tests
- Provider Tests

---

# 🔒 Authentication

- JWT Access Token
- Secure Password Hashing
- Protected Admin Endpoints
- Public Customer Endpoints

---

# 📊 Dashboard

Merchant dashboard provides live statistics:

- Total Appointments
- Pending
- Confirmed
- Completed
- Cancelled

Dashboard updates automatically after:

- New booking
- Confirmation
- Cancellation
- Completion

---

# 📱 Screens

- Role Selection
- Customer Home
- Business Detail
- Appointment Form
- Appointment Success
- Merchant Login
- Merchant Registration
- Merchant Dashboard
- Appointments
- Business Profile
- Google Calendar

---

# ⚙️ Installation

## Clone

```bash
git clone https://github.com/yourusername/sirasende.git

cd sirasende
```

---

## Backend

```bash
cd backend

python -m venv .venv

source .venv/bin/activate
```

Windows

```powershell
.venv\Scripts\activate
```

Install packages

```bash
pip install -r requirements.txt
```

Run database

```bash
docker compose up -d
```

Run migrations

```bash
alembic upgrade head
```

Start API

```bash
uvicorn app.main:app --reload
```

---

## Mobile

```bash
cd mobile

flutter pub get

flutter run
```

---

# 🧪 Testing

Backend

```bash
pytest
```

Flutter

```bash
flutter test
```

Static Analysis

```bash
flutter analyze
```

Build APK

```bash
flutter build apk --debug
```

---

# 📁 Project Structure

```
SıraSende
│
├── backend
│   ├── app
│   ├── alembic
│   ├── tests
│   └── Docker
│
├── mobile
│   ├── lib
│   ├── test
│   ├── assets
│   └── android
│
└── docs
```

---

# 🚦 API

Public

```
GET    /businesses

GET    /businesses/{slug}

GET    /businesses/{slug}/slots

POST   /businesses/{slug}/appointments
```

Admin

```
POST   /auth/login

POST   /auth/register

GET    /auth/me

GET    /admin/business

PUT    /admin/business

GET    /admin/appointments

PATCH  /admin/appointments/{id}

GET    /admin/appointments/summary

POST   /admin/google-calendar/connect

DELETE /admin/google-calendar/disconnect
```

---

# 🔍 Quality Assurance

✔ Clean Architecture

✔ Responsive UI

✔ JWT Authentication

✔ Google Calendar OAuth

✔ Provider State Management

✔ Repository Pattern

✔ Async Database

✔ Dockerized Backend

✔ Regression Tested

---

# 📈 Testing Status

Backend

```
331 Passed
```

Flutter

```
264 Passed
```

---

# 🚀 Future Improvements

- Push Notifications
- Email Notifications
- Multi-branch Businesses
- Employee Management
- Online Payments
- Appointment Reminders
- Customer Accounts
- Web Dashboard
- Analytics

---

# 👨‍💻 Development

This project was developed as a **Software Engineering Internship Project** following a mobile-first approach.

Main development principles:

- Clean Architecture
- SOLID Principles
- Repository Pattern
- Test-Driven Validation
- Markdown-Driven Development
- Secure Authentication
- Maintainable Codebase

---

<div align="center">

Made with ❤️ using Flutter & FastAPI

</div>
