import subprocess
import requests
import time
import threading
import matplotlib.pyplot as plt
import numpy as np

MAX_VMS = 3
HAPROXY_URL = "http://localhost/"
REQUEST_TOUT = 0.2  # seconds
EXPERIMENT_TIME = 240  # total experiment time in seconds, should match spam_schedule
UPDATE_INTERVAL = 1  # seconds

# Differences from tester:
# - Add spam shedule to test different request per second values,
# - Add NaN if VM is down
#

def get_addr(vm_number: int) -> str:
    return f"http://192.168.122.{100 + vm_number}:8000"

def run_ab(n_requests, concurrent, time_limit):
    subprocess.run(
        [
            "ab",
            f"-n{n_requests}",
            f"-c{concurrent}",
            f"-t{time_limit}",
            f"{HAPROXY_URL}/",
        ],
        check=True,
    )

def update(active_vms, all_vms, data_points, start_marks, stop_marks):
    still_active: list[str] = []
    for addr in active_vms:
        try:
            r = requests.get(f"{addr}/metrics/num_of_requests/1", timeout=REQUEST_TOUT)
            if r.status_code == 200:
                still_active.append(addr)
                data_points[addr].append((time.time(), r.json()["num_of_requests"]))
                print("succesful request")
            else:
                print(f"unsuccesful request, code {r.status_code}")
                stop_marks.append((time.time(), addr))
        except Exception:
            stop_marks.append((time.time(), addr))

    for addr in all_vms:
        if addr in still_active:
            continue
        try:
            r = requests.get(f"{addr}/status", timeout=REQUEST_TOUT)
            if r.status_code == 200:
                still_active.append(addr)
                start_marks.append((time.time(), addr))
                print(f"succesful request, addr: {addr}")
            else:
                print(f"unsuccesful request, addr: {addr}, code {r.status_code}")
        except Exception:
            pass
    return still_active

def request_spammer(url, schedule):
    for rps, duration in schedule:
        delay = 1.0 / rps
        end_time = time.time() + duration
        while time.time() < end_time:
            try:
                r = requests.get(url, timeout=2)
                if r.status_code != 200:
                    print("!!! haproxy returned error code !!!")
                    break
            except Exception:
                print("!!! haproxy couldn't be reached !!!")
            time.sleep(delay)

if __name__ == "__main__":
    data_points: dict[str, list[tuple[float, int]]] = {}
    start_marks: list[tuple[float, str]] = []
    stop_marks: list[tuple[float, str]] = []
    all_vms: list[str] = []

    for i in range(1, MAX_VMS + 1):
        addr = get_addr(i)
        data_points[addr] = []
        all_vms.append(addr)
    active_vms: list[str] = []

    spam_schedule = [
        (25 , 80)  # 25 RPS for 80s
        ,(15, 80)  # 15 RPS for 80s
        ,(25, 80)  # 25 RPS for 80s
    ]

    spam_thr = threading.Thread(
        target=request_spammer, args=(HAPROXY_URL, spam_schedule)
    )
    spam_thr.start()

    start = time.time()
    while (now := time.time()) - start < EXPERIMENT_TIME:
        active_vms = update(active_vms, all_vms, data_points, start_marks, stop_marks)
        time.sleep(max(0, UPDATE_INTERVAL - (time.time() - now)))

    spam_thr.join()

    print(data_points)

    for i, (addr, data) in enumerate(data_points.items(), start=1):
        if len(data) == 0:
            continue

        timestamps = []
        values = []
        prev_t = None
        for t, v in data:
            t_rel = t - start
            if prev_t is not None and t_rel - prev_t > UPDATE_INTERVAL * 1.5:
                timestamps.append(np.nan)
                values.append(np.nan)
            timestamps.append(t_rel)
            values.append(v)
            prev_t = t_rel

        plt.plot(timestamps, values, label=f"vm{i}")

    plt.xlabel("Time (s)")
    plt.ylabel("Number of Requests")
    plt.title("Number of Requests Handled by Each VM Over Time")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.show()