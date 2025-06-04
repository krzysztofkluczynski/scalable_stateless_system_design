from fastapi import FastAPI, Request
import time

app = FastAPI()
counter = 0
start_time = time.time()

@app.get("/")
async def root():
    global counter
    counter += 1
    return {"message": "Hello", "requests": counter}

@app.get("/metrics")
async def metrics():
    global counter
    elapsed = time.time() - start_time
    return {"requests": counter, "elapsed_seconds": elapsed}
