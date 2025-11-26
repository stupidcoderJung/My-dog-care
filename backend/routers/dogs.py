from fastapi import APIRouter, HTTPException
from schemas import DogCreate, DogResponse
from db import get_db_connection
from datetime import datetime

router = APIRouter(prefix="/dogs", tags=["dogs"])

@router.post("/", response_model=DogResponse)
async def create_dog(dog: DogCreate):
    con = get_db_connection()
    try:
        con.execute("""
            INSERT INTO dogs (id, name, breed, photo_id, created_at) 
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET 
                name = EXCLUDED.name,
                breed = EXCLUDED.breed,
                photo_id = EXCLUDED.photo_id
        """, (dog.id, dog.name, dog.breed, dog.photoId, datetime.now()))
        
        return DogResponse(
            id=dog.id,
            name=dog.name,
            breed=dog.breed,
            photoId=dog.photoId,
            createdAt=datetime.now()
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/", response_model=list[DogResponse])
async def get_dogs():
    con = get_db_connection()
    result = con.execute("SELECT id, name, breed, photo_id, created_at FROM dogs").fetchall()
    
    dogs = []
    for row in result:
        dogs.append(DogResponse(
            id=row[0],
            name=row[1],
            breed=row[2],
            photoId=row[3],
            createdAt=row[4]
        ))
    return dogs
