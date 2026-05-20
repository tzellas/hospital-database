#!/usr/bin/env python3
import argparse
import csv
import random
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

def read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def parse_dt(value):
    value = str(value).strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    return datetime.fromisoformat(value)

def doctor_score():
    # Medical care tends to be reviewed slightly better than food/cleanliness.
    return random.choices([1, 2, 3, 4, 5], weights=[3, 6, 18, 38, 35], k=1)[0]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", default="data")
    parser.add_argument("--out", default="data/doctor_reviews.csv")
    parser.add_argument("--coverage", type=float, default=0.80)
    parser.add_argument("--seed", type=int, default=72)
    args = parser.parse_args()

    random.seed(args.seed)
    data = Path(args.data_dir)

    hospitalizations = read_csv(data / "hospitalizations.csv")
    prescriptions = read_csv(data / "prescriptions.csv")

    if not hospitalizations:
        raise SystemExit("hospitalizations.csv is empty")
    if not prescriptions:
        raise SystemExit("prescriptions.csv is empty")

    discharge_by_hosp = {}
    patient_by_hosp = {}

    for idx, h in enumerate(hospitalizations, start=1):
        hid = h.get("hospitalization_id") or str(idx)
        patient_by_hosp[hid] = h["patient_id"]
        discharge_by_hosp[hid] = parse_dt(h["discharge_date"])

    doctors_by_hosp = defaultdict(set)

    for p in prescriptions:
        hid = p["hospitalization_id"]
        doctor_id = p["doctor_id"]
        patient_id = p["patient_id"]

        # Keep only prescriptions matching the hospitalization patient.
        if patient_by_hosp.get(hid) == patient_id:
            doctors_by_hosp[hid].add(doctor_id)

    rows = []
    used = set()

    for hid, doctors in doctors_by_hosp.items():
        if hid not in discharge_by_hosp:
            continue

        for doctor_id in sorted(doctors, key=lambda x: int(x)):
            if random.random() > args.coverage:
                continue

            key = (patient_by_hosp[hid], doctor_id, hid)
            if key in used:
                continue
            used.add(key)

            review_date = discharge_by_hosp[hid].date() + timedelta(days=random.randint(1, 30))

            rows.append([
                patient_by_hosp[hid],
                doctor_id,
                hid,
                doctor_score(),
                review_date.isoformat()
            ])

    with open(args.out, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "patient_id",
            "doctor_id",
            "hospitalization_id",
            "medical_care_score",
            "review_date"
        ])
        w.writerows(rows)

    print(f"Wrote {len(rows)} rows to {args.out}")

if __name__ == "__main__":
    main()
