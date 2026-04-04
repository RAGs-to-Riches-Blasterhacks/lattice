from fastapi import APIRouter

router = APIRouter()


@router.get("/items", tags=["items"])
def list_items():
    return {"items": []}


@router.get("/items/{item_id}", tags=["items"])
def get_item(item_id: int):
    return {"item_id": item_id}
