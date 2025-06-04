import subprocess
import requests
import time
import threading
import matplotlib.pyplot as plt


MAX_VMS = 4
HAPROXY_URL = "http://localhost/"
REQUEST_TOUT = 0.2  # seconds
EXPERIMENT_TIME = 30  # seconds
UPDATE_INTERVAL = 1  # seconds


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
        except Exception as e:
            # print("exception in trying active")
            # raise e
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
        except Exception as e:
            # print("exception in trying inactive")
            # raise e
            pass
    return still_active


def request_spammer(url, rps, duration):
    delay = 1.0 / rps
    end_time = time.time() + duration

    while time.time() < end_time:
        try:
            r = requests.get(url, timeout=2)
            if r.status_code != 200:
                print("!!! haproxy returned error code !!!")
                break
            # count += 1
        except Exception as e:
            print("!!! haproxy couldn't be reached !!!")
            raise e
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

    spam_thr = threading.Thread(
        target=request_spammer, args=(HAPROXY_URL, 20, EXPERIMENT_TIME)
    )
    spam_thr.start()

    start = time.time()
    while (now := time.time()) - start < EXPERIMENT_TIME:
        active_vms = update(active_vms, all_vms, data_points, start_marks, stop_marks)
        time.sleep(UPDATE_INTERVAL - (time.time() - now))

    spam_thr.join()

    print(data_points)
    for data in data_points.values():
        if len(data) == 0:
            continue
        timestamps, values = zip(*data)
        timestamps = [t - start for t in timestamps]
        plt.plot(timestamps, values)
    plt.show()
