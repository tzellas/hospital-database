#!/usr/bin/env python3
import argparse
import csv
import random
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

SURGICAL_SPECIALTIES = {
    "General Surgery",
    "Surgical Oncology",
    "Trauma Surgery",
    "Neurosurgery",
    "Spine Surgery",
    "Orthopedics",
    "Traumatology",
    "Sports Medicine",
    "Urology",
    "Endourology",
    "Urologic Oncology",
    "Obstetrics and Gynecology",
    "Gynecologic Oncology",
}

def read_dict(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def read_no_header(path, cols):
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        for r in csv.reader(f):
            if len(r) >= len(cols):
                rows.append(dict(zip(cols, [x.strip() for x in r])))
    return rows

def parse_dt(x):
    x = str(x).strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(x, fmt)
        except ValueError:
            pass
    return datetime.fromisoformat(x)

def overlaps(a_start, a_end, b_start, b_end):
    return a_start < b_end and b_start < a_end

def first_free_room(room_ids, start, end, room_busy):
    for room_id in room_ids:
        if all(not overlaps(start, end, s, e) for s, e in room_busy[room_id]):
            return room_id
    return None

def is_free(staff_id, start, end, busy):
    return all(not overlaps(start, end, s, e) for s, e in busy[staff_id])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default="data")
    ap.add_argument("--count", type=int, default=150)
    ap.add_argument("--seed", type=int, default=44)
    args = ap.parse_args()

    random.seed(args.seed)
    data = Path(args.data_dir)

    hospitalizations = read_dict(data / "hospitalizations.csv")
    departments = read_dict(data / "departments.csv")
    staff = read_dict(data / "staff.csv")
    doctors = read_no_header(data / "doctors.csv", ["medical_license_num", "specialty", "rank"])
    procedures = read_no_header(data / "medical_procedures.csv", ["procedure_code", "description", "category", "default_cost"])
    rooms = read_dict(data / "procedure_rooms.csv")
    nurse_rows = read_no_header(data / "nurse_department_rank.csv", ["rank", "department_name"])

    dept_name_to_id = {}
    manager_ids = set()

    for i, d in enumerate(departments, start=1):
        dep_id = int(d.get("department_id") or i)
        name = d.get("name") or d.get("department_name")
        dept_name_to_id[name] = dep_id
        if d.get("manager_id"):
            manager_ids.add(int(d["manager_id"]))

    doctor_staff_ids = [
        i for i, s in enumerate(staff, start=1)
        if s["staff_type"].strip().upper() == "DOCTOR"
    ]

    nurse_staff_ids = [
        i for i, s in enumerate(staff, start=1)
        if s["staff_type"].strip().upper() == "NURSE"
    ]

    spec_to_deps = defaultdict(set)
    with open(data / "dept_specialty_map.csv", encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            dep_name = row["department_name"].strip()
            spec = row["specialty"].strip()
            if dep_name in dept_name_to_id:
                spec_to_deps[spec].add(dept_name_to_id[dep_name])

    doctor_by_dep = defaultdict(list)
    surgeon_by_dep = defaultdict(list)

    non_director_doctor_ids = [sid for sid in doctor_staff_ids if sid not in manager_ids]

    for staff_id, doc in zip(non_director_doctor_ids, doctors):
        specialty = doc["specialty"].strip()
        for dep_id in spec_to_deps.get(specialty, set()):
            doctor_by_dep[dep_id].append(staff_id)
            if specialty in SURGICAL_SPECIALTIES:
                surgeon_by_dep[dep_id].append(staff_id)

    nurse_by_dep = defaultdict(list)
    for staff_id, nr in zip(nurse_staff_ids, nurse_rows):
        dep_id = dept_name_to_id.get(nr["department_name"])
        if dep_id:
            nurse_by_dep[dep_id].append(staff_id)

    operating_rooms = []
    procedure_rooms = []

    for i, r in enumerate(rooms, start=1):
        room_type = r["room_type"].strip()
        if room_type == "OPERATING_ROOM":
            operating_rooms.append(i)
        elif room_type == "PROCEDURE_ROOM":
            procedure_rooms.append(i)

    if not hospitalizations:
        raise SystemExit("hospitalizations.csv is empty")
    if not procedures:
        raise SystemExit("medical_procedures.csv is empty")
    if not operating_rooms:
        raise SystemExit("procedure_rooms.csv has no OPERATING_ROOM")
    if not procedure_rooms:
        raise SystemExit("procedure_rooms.csv has no PROCEDURE_ROOM")

    room_busy = defaultdict(list)
    staff_busy = defaultdict(list)

    proc_rows = []
    schedule_rows = []
    assistant_rows = []

    attempts = 0
    max_attempts = args.count * 400

    while len(proc_rows) < args.count and attempts < max_attempts:
        attempts += 1

        h_index = random.randrange(len(hospitalizations))
        h = hospitalizations[h_index]
        dep_id = int(h["department_id"])

        proc = random.choice(procedures)
        category = proc["category"].strip().upper()

        if category == "SURGICAL":
            main_candidates = surgeon_by_dep.get(dep_id, [])
            valid_rooms = operating_rooms
            duration = random.randint(90, 240)
        elif category == "DIAGNOSTIC":
            main_candidates = doctor_by_dep.get(dep_id, [])
            valid_rooms = procedure_rooms
            duration = random.randint(30, 90)
        else:
            main_candidates = doctor_by_dep.get(dep_id, [])
            valid_rooms = procedure_rooms
            duration = random.randint(45, 150)

        if not main_candidates:
            continue

        admission = parse_dt(h["admission_date"])
        discharge = parse_dt(h["discharge_date"])

        if discharge <= admission:
            discharge = admission + timedelta(days=1)

        earliest_start = admission + timedelta(hours=6)
        latest_start = discharge - timedelta(minutes=duration + 120)

        if latest_start <= earliest_start:
            continue

        span_minutes = int((latest_start - earliest_start).total_seconds() // 60)
        start = earliest_start + timedelta(minutes=random.randint(0, span_minutes))
        start = start.replace(minute=(start.minute // 15) * 15, second=0, microsecond=0)
        end = start + timedelta(minutes=duration)

        room_id = first_free_room(valid_rooms, start, end, room_busy)
        if room_id is None:
            continue

        random.shuffle(main_candidates)
        main_doctor = None
        for doctor_id in main_candidates:
            if is_free(doctor_id, start, end, staff_busy):
                main_doctor = doctor_id
                break

        if main_doctor is None:
            continue

        try:
            base_cost = float(proc["default_cost"])
        except ValueError:
            base_cost = random.uniform(500, 3000)

        procedure_id = len(proc_rows) + 1
        actual_cost = round(base_cost * random.uniform(0.85, 1.25), 2)

        hospitalization_id = h.get("hospitalization_id") or str(h_index + 1)

        proc_rows.append([
            hospitalization_id,
            proc["procedure_code"],
            main_doctor,
            duration,
            f"{actual_cost:.2f}",
        ])

        schedule_rows.append([
            procedure_id,
            room_id,
            start.strftime("%Y-%m-%d %H:%M:%S"),
            end.strftime("%Y-%m-%d %H:%M:%S"),
        ])

        room_busy[room_id].append((start, end))
        staff_busy[main_doctor].append((start, end))

        used_staff = {main_doctor}

        assistant_doctors = [
            d for d in doctor_by_dep.get(dep_id, [])
            if d != main_doctor and is_free(d, start, end, staff_busy)
        ]

        if assistant_doctors and random.random() < 0.75:
            assistant = random.choice(assistant_doctors)
            assistant_rows.append([procedure_id, assistant, "Assistant Doctor"])
            staff_busy[assistant].append((start, end))
            used_staff.add(assistant)

        dep_nurses = [
            n for n in nurse_by_dep.get(dep_id, [])
            if n not in used_staff and is_free(n, start, end, staff_busy)
        ]

        random.shuffle(dep_nurses)
        nurse_count = random.randint(1, 2)

        for nurse_id in dep_nurses[:nurse_count]:
            assistant_rows.append([procedure_id, nurse_id, "Procedure Nurse"])
            staff_busy[nurse_id].append((start, end))
            used_staff.add(nurse_id)

    if len(proc_rows) < args.count:
        raise SystemExit(f"Could only create {len(proc_rows)} procedures, requested {args.count}")

    out1 = data / "hospitalization_medical_procedures.csv"
    out2 = data / "procedure_room_schedule.csv"
    out3 = data / "assistant_procedure_staff.csv"

    with open(out1, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["hospitalization_id", "procedure_code", "main_doctor_id", "actual_duration_minutes", "actual_cost"])
        w.writerows(proc_rows)

    with open(out2, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["procedure_id", "room_id", "start_datetime", "end_datetime"])
        w.writerows(schedule_rows)

    with open(out3, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["procedure_id", "staff_id", "role_in_procedure"])
        w.writerows(assistant_rows)

    print(f"Wrote {len(proc_rows)} rows to {out1}")
    print(f"Wrote {len(schedule_rows)} rows to {out2}")
    print(f"Wrote {len(assistant_rows)} rows to {out3}")
    print("Surgical procedures use surgeon-type main doctors only.")

if __name__ == "__main__":
    main()
