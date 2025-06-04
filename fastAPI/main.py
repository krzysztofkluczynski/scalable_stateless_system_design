from fastapi import FastAPI, Request, Path
import time
from collections import deque


app = FastAPI()
counter = 0
start_time = time.time()
requests_timestamps = deque(maxlen=10000)


@app.get("/")
async def root():
    global counter, requests_timestamps
    counter += 1
    requests_timestamps.append(time.time())
    return {"message": "Hello", "requests": counter}


@app.get("/status")
async def status():
    return {"status": "OK"}


@app.get("/metrics")
async def metrics():
    global counter
    elapsed = time.time() - start_time
    return {"requests": counter, "elapsed_seconds": elapsed}


@app.get("/metrics/num_of_requests/{period}")
async def number_of_requests(period: float = Path(..., gt=0)):
    global requests_timestamps
    now = time.time()
    num = len(
        [timestamp for timestamp in requests_timestamps if now - timestamp < period]
    )
    return {"period": period, "num_of_requests": num}


@app.get("/metrics/total_history")
async def total_history():
    return {"data": requests_timestamps}
