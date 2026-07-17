from fastapi import APIRouter

from app.api.v1 import auth, businesses

api_router = APIRouter()
api_router.include_router(businesses.router)
api_router.include_router(auth.router)

