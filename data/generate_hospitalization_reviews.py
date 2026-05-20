#!/usr/bin/env python3
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

DATA_DIR = Path("data")
OUT_PATH = DATA_DIR / "hospitalization_reviews.csv"
COVERAGE = 0.91
SEED = 71

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

def weighted_score():
    # More realistic: most reviews are 3-5, fewer are 1-2.
    return random.choices([1, 2, 3, 4, 5], weights=[4, 8, 22, 36, 30], k=1)[0]

def correlated_scores():
    overall = weighted_score()

    def near(base):
        delta = random.choices([-2, -1, 0, 1, 2], weights=[5, 18, 50, 22, 5], k=1)[0]
        return max(1, min(5, base + delta))

    nursing = near(overall)
    cleanliness = near(overall)
    food = near(overall)
    return nursing, cleanliness, food, overall

def main():
    random.seed(SEED)
    data = DATA_DIR

    hospitalizations = read_csv(data / "hospitalizations.csv")
    if not hospitalizations:
        raise SystemExit("hospitalizations.csv is empty")

    rows = []

    for idx, h in enumerate(hospitalizations, start=1):
        discharge_raw = str(h.get("discharge_date", "")).strip()
        if not discharge_raw:
            continue

        if random.random() > COVERAGE:
            continue

        hospitalization_id = h.get("hospitalization_id") or str(idx)
        patient_id = h["patient_id"]

        discharge = parse_dt(discharge_raw)
        review_date = discharge.date() + timedelta(days=random.randint(1, 30))

        nursing, cleanliness, food, overall = correlated_scores()

        rows.append([
            patient_id,
            hospitalization_id,
            nursing,
            cleanliness,
            food,
            overall,
            review_date.isoformat()
        ])

    with open(OUT_PATH, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "patient_id",
            "hospitalization_id",
            "nursing_care_score",
            "cleanliness_score",
            "food_score",
            "overall_experience_score",
            "review_date"
        ])
        w.writerows(rows)

    print(f"Wrote {len(rows)} rows to {OUT_PATH}")

if __name__ == "__main__":
    main()
