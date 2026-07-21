from fastapi import APIRouter

from app.api.v1 import admin_appointments, auth, businesses

api_router = APIRouter()
api_router.include_router(businesses.router)
api_router.include_router(auth.router)
api_router.include_router(admin_appointments.router)
