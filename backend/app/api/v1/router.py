from fastapi import APIRouter

from app.api.v1 import businesses

api_router = APIRouter()
api_router.include_router(businesses.router)

