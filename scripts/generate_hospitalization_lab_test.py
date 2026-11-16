#!/usr/bin/env python3
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
OUT_PATH = DATA_DIR / "hospitalization_lab_tests.csv"
COUNT = 1150
SEED = 21

def read_dict_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def read_lab_tests(path):
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        for row in csv.reader(f):
            if len(row) < 3:
                continue
            code = row[0].strip()
            name = row[1].strip()
            cost = row[2].strip()
            if not code:
                continue
            rows.append({
                "test_code": code,
                "test_name": name,
                "cost": cost
            })
    return rows

def parse_datetime(value):
    value = str(value).strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    return datetime.fromisoformat(value)

def main():
    random.seed(SEED)
    data = DATA_DIR

    hospitalizations = read_dict_csv(data / "hospitalizations.csv")
    lab_tests = read_lab_tests(data / "lab_tests.csv")
    staff = read_dict_csv(data / "staff.csv")

    doctor_ids = [
        idx
        for idx, row in enumerate(staff, start=1)
        if row["staff_type"].strip().upper() == "DOCTOR"
    ]

    if not hospitalizations:
        raise SystemExit("hospitalizations.csv is empty")
    if not lab_tests:
        raise SystemExit("lab_tests.csv is empty")
    if not doctor_ids:
        raise SystemExit("staff.csv has no DOCTOR rows")

    output_rows = []

    for _ in range(COUNT):
        h_index = random.randrange(len(hospitalizations))
        h = hospitalizations[h_index]
        test = random.choice(lab_tests)

        hospitalization_id = h.get("hospitalization_id") or h.get("id") or str(h_index + 1)

        admission = parse_datetime(h["admission_date"])
        discharge = parse_datetime(h["discharge_date"])
        if discharge <= admission:
            discharge = admission + timedelta(days=1)

        available_minutes = int((discharge - admission).total_seconds() // 60)
        offset = random.randint(60, max(60, available_minutes - 60))
        test_date = admission + timedelta(minutes=offset)

        try:
            base_cost = float(test["cost"])
        except ValueError:
            base_cost = random.uniform(15, 100)

        actual_cost = round(base_cost * random.uniform(0.90, 1.20), 2)

        name = test["test_name"].upper()
        if any(word in name for word in ["ΑΚΤΙΝΟΓΡΑΦΙΑ", "ΜΥΕΛΟΓΡΑΦΙΑ", "ΤΟΜΟΓΡΑΦΙΑ", "ΥΠΕΡΗΧΟ"]):
            result_text = random.choice([
                "Χωρίς οξέα παθολογικά ευρήματα",
                "Ήπια παθολογικά ευρήματα",
                "Συνιστάται περαιτέρω κλινική συσχέτιση"
            ])
            result_value = ""
            result_unit = ""
        else:
            if random.random() < 0.6:
                result_text = ""
                result_value = round(random.uniform(1, 200), 2)
                result_unit = random.choice(["mg/dL", "g/dL", "U/L", "mmol/L"])
            else:
                result_text = random.choice([
                    "Φυσιολογικό αποτέλεσμα",
                    "Παθολογικό αποτέλεσμα",
                    "Οριακό αποτέλεσμα"
                ])
                result_value = ""
                result_unit = ""

        output_rows.append([
            hospitalization_id,
            random.choice(doctor_ids),
            test["test_code"],
            test_date.strftime("%Y-%m-%d %H:%M:%S"),
            result_text,
            result_value,
            result_unit,
            f"{actual_cost:.2f}"
        ])

    with open(OUT_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "hospitalization_id",
            "ordered_by_doctor_id",
            "test_code",
            "test_date",
            "result_text",
            "result_value",
            "result_unit",
            "actual_cost"
        ])
        writer.writerows(output_rows)

    print(f"Wrote {len(output_rows)} rows to {OUT_PATH}")

if __name__ == "__main__":
    main()
