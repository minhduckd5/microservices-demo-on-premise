import datetime
from decimal import Decimal

from pydantic import BaseModel


class CategoryOut(BaseModel):
    id: str
    name: str
    slug: str

    model_config = {"from_attributes": True}


class ProductOut(BaseModel):
    id: str
    name: str
    slug: str
    description: str
    price: Decimal
    stock: int
    category_id: str | None
    image_url: str | None
    created_at: datetime.datetime

    model_config = {"from_attributes": True}
