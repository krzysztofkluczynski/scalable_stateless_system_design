from fastapi import FastAPI

# Create an instance of the FastAPI class
app = FastAPI()

# A simple endpoint that returns 'OK'
@app.get("/")
def read_root():
    return {"status": "OK"}
