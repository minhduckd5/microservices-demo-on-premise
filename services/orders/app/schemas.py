import datetime
from decimal import Decimal

from pydantic import BaseModel


class OrderItemCreate(BaseModel):
    product_id: str
    quantity: int
    unit_price: Decimal


class OrderCreate(BaseModel):
    user_id: str
    items: list[OrderItemCreate]


class OrderItemOut(BaseModel):
    id: str
    order_id: str
    product_id: str
    quantity: int
    unit_price: Decimal

    model_config = {"from_attributes": True}


class OrderOut(BaseModel):
    id: str
    user_id: str
    status: str
    total: Decimal
    created_at: datetime.datetime
    items: list[OrderItemOut] = []

    model_config = {"from_attributes": True}
