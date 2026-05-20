#!/usr/bin/env python3
import csv
import random
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

DATA_DIR = Path("data")
OUT_PATH = DATA_DIR / "prescriptions.csv"
COUNT = 1200
SEED = 55

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

def read_active_substances(path):
    substances = {}
    with open(path, encoding="utf-8-sig", newline="") as f:
        for i, row in enumerate(csv.reader(f), start=1):
            if row and row[0].strip():
                substances[row[0].strip()] = i
    return substances

def parse_dt(x):
    x = str(x).strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(x, fmt)
        except ValueError:
            pass
    return datetime.fromisoformat(x)

def main():
    random.seed(SEED)
    data = DATA_DIR

    hospitalizations = read_dict(data / "hospitalizations.csv")
    staff = read_dict(data / "staff.csv")
    doctors = read_no_header(data / "doctors.csv", ["medical_license_num", "specialty", "rank"])
    departments = read_dict(data / "departments.csv")
    allergies = read_dict(data / "allergies.csv")
    drug_rows = read_dict(data / "drug.csv")
    drug_substance_rows = read_dict(data / "drug_active_substances_stage.csv")
    active_name_to_id = read_active_substances(data / "active_substances_unique.csv")

    if not hospitalizations:
        raise SystemExit("hospitalizations.csv is empty")
    if not drug_rows:
        raise SystemExit("drug.csv is empty")
    if not drug_substance_rows:
        raise SystemExit("drug_active_substances_stage.csv is empty")

    dept_name_to_id = {}
    manager_ids = set()
    for i, d in enumerate(departments, start=1):
        dep_id = int(d.get("department_id") or i)
        name = d.get("name") or d.get("department_name")
        dept_name_to_id[name] = dep_id
        if d.get("manager_id"):
            manager_ids.add(int(d["manager_id"]))

    spec_to_deps = defaultdict(set)
    with open(data / "dept_specialty_map.csv", encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            dep_name = row["department_name"].strip()
            spec = row["specialty"].strip()
            if dep_name in dept_name_to_id:
                spec_to_deps[spec].add(dept_name_to_id[dep_name])

    doctor_staff_ids = [
        i for i, row in enumerate(staff, start=1)
        if row["staff_type"].strip().upper() == "DOCTOR"
    ]

    non_director_doctor_ids = [sid for sid in doctor_staff_ids if sid not in manager_ids]

    doctors_by_dep = defaultdict(list)
    for staff_id, doc in zip(non_director_doctor_ids, doctors):
        specialty = doc["specialty"].strip()
        for dep_id in spec_to_deps.get(specialty, set()):
            doctors_by_dep[dep_id].append(staff_id)

    # Also allow department managers/directors to prescribe in their own department.
    for d in departments:
        if d.get("manager_id"):
            dep_id = int(d.get("department_id") or list(dept_name_to_id.values())[0])
            doctors_by_dep[dep_id].append(int(d["manager_id"]))

    patient_allergies = defaultdict(set)
    for a in allergies:
        patient_id = int(a["patient_id"])
        substance_id = int(a["substance_id"])
        patient_allergies[patient_id].add(substance_id)

    drug_substances = defaultdict(set)
    for r in drug_substance_rows:
        drug_id = int(r["drug_id"])
        substance_name = r["active_substance"].strip()
        substance_id = active_name_to_id.get(substance_name)
        if substance_id:
            drug_substances[drug_id].add(substance_id)

    all_drug_ids = list(range(1, len(drug_rows) + 1))
    safe_drugs_cache = {}

    def safe_drugs_for_patient(patient_id):
        if patient_id in safe_drugs_cache:
            return safe_drugs_cache[patient_id]
        bad = patient_allergies.get(patient_id, set())
        safe = [
            drug_id for drug_id in all_drug_ids
            if not (drug_substances.get(drug_id, set()) & bad)
        ]
        safe_drugs_cache[patient_id] = safe
        return safe

    dosage_options = [
        "1 tablet",
        "2 tablets",
        "5 ml",
        "10 ml",
        "1 capsule",
        "500 mg",
        "1000 mg",
        "1 ampoule",
    ]

    frequency_options = [
        "once daily",
        "twice daily",
        "three times daily",
        "every 8 hours",
        "every 12 hours",
        "as needed",
    ]

    prescriptions = []
    used_unique = set()
    attempts = 0
    max_attempts = COUNT * 200

    while len(prescriptions) < COUNT and attempts < max_attempts:
        attempts += 1

        h_index = random.randrange(len(hospitalizations))
        h = hospitalizations[h_index]

        hospitalization_id = int(h.get("hospitalization_id") or h_index + 1)
        patient_id = int(h["patient_id"])
        department_id = int(h["department_id"])

        doctor_candidates = doctors_by_dep.get(department_id, [])
        if not doctor_candidates:
            continue

        safe_drugs = safe_drugs_for_patient(patient_id)
        if not safe_drugs:
            continue

        doctor_id = random.choice(doctor_candidates)
        drug_id = random.choice(safe_drugs)

        admission = parse_dt(h["admission_date"])
        discharge = parse_dt(h["discharge_date"])
        if discharge <= admission:
            discharge = admission + timedelta(days=1)

        stay_days = max(1, (discharge.date() - admission.date()).days)
        start_offset = random.randint(0, max(0, min(stay_days - 1, 7)))
        start_date = admission.date() + timedelta(days=start_offset)

        max_duration = max(1, (discharge.date() - start_date).days + 1)
        duration = random.randint(1, min(max_duration, 14))
        end_date = start_date + timedelta(days=duration - 1)
        if end_date > discharge.date():
            end_date = discharge.date()

        unique_key = (doctor_id, patient_id, drug_id, start_date.isoformat())
        if unique_key in used_unique:
            continue
        used_unique.add(unique_key)

        prescriptions.append([
            hospitalization_id,
            patient_id,
            doctor_id,
            drug_id,
            random.choice(dosage_options),
            random.choice(frequency_options),
            start_date.isoformat(),
            end_date.isoformat(),
        ])

    if len(prescriptions) < COUNT:
        raise SystemExit(f"Could only create {len(prescriptions)} prescriptions, requested {COUNT}")

    with open(OUT_PATH, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "hospitalization_id",
            "patient_id",
            "doctor_id",
            "drug_id",
            "dosage",
            "frequency",
            "start_date",
            "end_date",
        ])
        w.writerows(prescriptions)

    print(f"Wrote {len(prescriptions)} rows to {OUT_PATH}")
    print("All prescriptions avoid patient active-substance allergies.")

if __name__ == "__main__":
    main()
