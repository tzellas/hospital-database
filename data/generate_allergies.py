#!/usr/bin/env python3
import argparse
import csv
import random
from pathlib import Path

def count_data_rows(path, has_header=True):
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f))
    if has_header:
        return max(0, len(rows) - 1)
    return len([r for r in rows if r and str(r[0]).strip()])

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", default="data")
    parser.add_argument("--out", default="data/allergies.csv")
    parser.add_argument("--count", type=int, default=250)
    parser.add_argument("--seed", type=int, default=31)
    args = parser.parse_args()

    random.seed(args.seed)
    data = Path(args.data_dir)

    patient_count = count_data_rows(data / "patients.csv", has_header=True)
    substance_count = count_data_rows(data / "active_substances_unique.csv", has_header=False)

    if patient_count == 0:
        raise SystemExit("patients.csv has no patients")
    if substance_count == 0:
        raise SystemExit("active_substances_unique.csv has no active substances")

    max_pairs = patient_count * substance_count
    target = min(args.count, max_pairs)

    pairs = set()
    while len(pairs) < target:
        patient_id = random.randint(1, patient_count)
        substance_id = random.randint(1, substance_count)
        pairs.add((patient_id, substance_id))

    rows = sorted(pairs)

    with open(args.out, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["patient_id", "substance_id"])
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {args.out}")

if __name__ == "__main__":
    main()
