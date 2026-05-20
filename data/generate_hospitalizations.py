#!/usr/bin/env python3
import csv, random, glob
from collections import defaultdict
from datetime import datetime, timedelta, date, time
from pathlib import Path

DATA_DIR = Path('data')
OUT_PATH = DATA_DIR / 'hospitalizations.csv'
N = 500
SEED = 42
START_DATE = '2025-03-20'
END_DATE = '2026-03-19'

HOSP_COLS = [
    'patient_id','department_id','bed_num','admission_date','discharge_date',
    'admission_icd10_code','discharge_icd10_code','ken_code','total_cost','extra_charge'
]

def die(msg):
    raise SystemExit('ERROR: ' + msg)

def clean(x):
    return str(x or '').strip()

def find_file(data, name):
    p = data / name
    if p.exists(): return p
    hits = sorted(glob.glob(str(data / (name.replace('.csv','') + '*.csv'))))
    if hits: return Path(hits[0])
    die(f'missing {name}')

def read_rows(path, fallback=None):
    txt = path.read_text(encoding='utf-8-sig').splitlines()
    if not txt: return []
    first = [clean(x) for x in next(csv.reader([txt[0]]))]
    has_header = fallback is None or any(x in first for x in fallback)
    with path.open(encoding='utf-8-sig', newline='') as fp:
        if has_header:
            return [{clean(k): clean(v) for k, v in r.items()} for r in csv.DictReader(fp)]
        return [dict(zip(fallback, map(clean, r))) for r in csv.reader(fp)]

def main():
    random.seed(SEED)
    data = DATA_DIR

    # ids after COPY into serial tables follow file row order, assuming clean DB/load order.
    patients = read_rows(find_file(data, 'patients.csv'))
    if not patients: die('patients.csv is empty')
    patient_ids = list(range(1, len(patients) + 1))

    deps = read_rows(find_file(data, 'departments.csv'))
    dep_name_to_id = {}
    for i, r in enumerate(deps, 1):
        name = clean(r.get('name') or r.get('department_name'))
        if name: dep_name_to_id[name] = i
    if not dep_name_to_id: die('no departments found')

    beds_by_dep = defaultdict(list)
    for r in read_rows(find_file(data, 'beds.csv')):
        dep = clean(r.get('department') or r.get('department_name') or r.get('dep'))
        bed = clean(r.get('bed_num') or r.get('bed_number') or r.get('bed'))
        status = clean(r.get('status')).upper()
        if dep in dep_name_to_id and bed and status != 'UNDER_MAINTENANCE':
            beds_by_dep[dep].append(bed)
    beds_by_dep = {d: sorted(set(bs)) for d, bs in beds_by_dep.items() if bs}
    if not beds_by_dep: die('no usable beds found in beds.csv')

    icd_rows = read_rows(find_file(data, 'icd10.csv'), ['icd10_code','description'])
    icds = [clean(r.get('icd10_code')) for r in icd_rows if clean(r.get('icd10_code'))]
    if not icds: die('no icd10 codes found')

    ken_rows = read_rows(find_file(data, 'ken.csv'), ['ken_code','description','base_cost','average_length_of_stay'])
    kens = []
    for r in ken_rows:
        code = clean(r.get('ken_code'))
        if not code: continue
        try:
            base = float(clean(r.get('base_cost')).replace(',', '.'))
            los = int(float(clean(r.get('average_length_of_stay')).replace(',', '.')))
            if los <= 0: continue
        except Exception:
            continue
        kens.append((code, base, los))
    if not kens: die('no usable ken rows found')

    start = date.fromisoformat(START_DATE)
    end = date.fromisoformat(END_DATE)
    if end < start: die('end-date before start-date')
    total_days = (end - start).days + 1

    # Track latest discharge per bed. This simple rule guarantees no overlapping bed stays.
    next_free = {}
    all_beds = []
    for dep, beds in beds_by_dep.items():
        for bed in beds:
            next_free[(dep, bed)] = datetime.combine(start, time(0, 0))
            all_beds.append((dep, bed))
    if not all_beds: die('no beds available')

    out = []
    for i in range(N):
        dep, bed = all_beds[i % len(all_beds)]
        ken_code, base, avg_los = random.choice(kens)
        stay_days = random.randint(1, max(2, min(14, avg_los + 5)))

        # Spread admissions, but never before bed is free.
        wanted = datetime.combine(start + timedelta(days=random.randint(0, max(0, total_days - 2))), time(random.choice([7,9,11,13,15,17]), 0))
        adm = max(wanted, next_free[(dep, bed)] + timedelta(hours=1))
        dis = adm + timedelta(days=stay_days, hours=random.choice([8,10,12]))

        # Keep generated completed stays inside a sane range; if near end, shorten.
        hard_end = datetime.combine(end + timedelta(days=1), time(23, 0))
        if dis > hard_end:
            dis = hard_end
            if dis <= adm:
                adm = dis - timedelta(days=1)

        next_free[(dep, bed)] = dis
        extra_days = max(0, stay_days - avg_los)
        extra = round(extra_days * (base / avg_los), 2)
        total = round(base + extra, 2)
        adm_icd = random.choice(icds)
        dis_icd = random.choice(icds)
        patient_id = patient_ids[i % len(patient_ids)]

        out.append([
            patient_id,
            dep_name_to_id[dep],
            bed,
            adm.strftime('%Y-%m-%d %H:%M:%S'),
            dis.strftime('%Y-%m-%d %H:%M:%S'),
            adm_icd,
            dis_icd,
            ken_code,
            f'{total:.2f}',
            f'{extra:.2f}',
        ])

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, 'w', newline='', encoding='utf-8') as fp:
        w = csv.writer(fp)
        w.writerow(HOSP_COLS)
        w.writerows(out)
    print(f'Wrote {len(out)} rows to {OUT_PATH}')

if __name__ == '__main__':
    main()
