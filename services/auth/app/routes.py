import datetime
import uuid

import redis.asyncio as aioredis
from app.config import settings
from app.database import get_db
from app.models import Session, User
from app.schemas import TokenOut, UserCreate, UserLogin, UserOut
from fastapi import APIRouter, Cookie, Depends, HTTPException, Response
from jose import jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def _hash_password(password: str) -> str:
    return pwd_context.hash(password)


def _verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _create_jwt(user_id: str) -> str:
    expire = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(
        minutes=settings.access_token_expire_minutes
    )
    return jwt.encode(
        {"sub": user_id, "exp": expire},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


async def _get_redis() -> aioredis.Redis:
    return aioredis.from_url(settings.redis_url, decode_responses=True)


@router.post("/register", response_model=UserOut, status_code=201)
async def register(payload: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered")
    user = User(
        id=str(uuid.uuid4()),
        email=payload.email,
        hashed_password=_hash_password(payload.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/login", response_model=TokenOut)
async def login(
    payload: UserLogin,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == payload.email))
    user: User | None = result.scalar_one_or_none()
    if not user or not _verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = _create_jwt(user.id)
    session_id = str(uuid.uuid4())
    expires_at = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(
        minutes=settings.access_token_expire_minutes
    )
    session = Session(
        id=session_id,
        user_id=user.id,
        token=token,
        expires_at=expires_at,
    )
    db.add(session)
    await db.commit()

    redis = await _get_redis()
    ttl = settings.access_token_expire_minutes * 60
    await redis.setex(f"session:{session_id}", ttl, user.id)
    await redis.aclose()

    response.set_cookie(
        key="session_id",
        value=session_id,
        httponly=True,
        secure=settings.cookie_secure,
        max_age=ttl,
        samesite="lax",
    )
    return TokenOut(access_token=token)


@router.post("/logout")
async def logout(
    response: Response,
    session_id: str | None = Cookie(default=None),
    db: AsyncSession = Depends(get_db),
):
    if session_id:
        result = await db.execute(select(Session).where(Session.id == session_id))
        session = result.scalar_one_or_none()
        if session:
            await db.delete(session)
            await db.commit()
        redis = await _get_redis()
        await redis.delete(f"session:{session_id}")
        await redis.aclose()
    response.delete_cookie("session_id")
    return {"message": "Logged out"}


@router.get("/me", response_model=UserOut)
async def me(
    session_id: str | None = Cookie(default=None),
    db: AsyncSession = Depends(get_db),
):
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    redis = await _get_redis()
    user_id = await redis.get(f"session:{session_id}")
    await redis.aclose()

    if not user_id:
        raise HTTPException(status_code=401, detail="Session expired")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
