#!/usr/bin/env python3
import csv, random, glob
from collections import defaultdict
from datetime import datetime, timedelta, date, time
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
OUT_PATH = DATA_DIR / 'hospitalizations.csv'
N = 1850
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
    if name == 'patients.csv':
        alt = data / 'patient.csv'
        if alt.exists(): return alt
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

def make_row(patient_id, dep, bed, adm, dis, dep_name_to_id, icds, kens):
    ken_code, base, avg_los = random.choice(kens)
    stay_days = max(1, (dis.date() - adm.date()).days)
    extra_days = max(0, stay_days - avg_los)
    extra = round(extra_days * (base / avg_los), 2)
    total = round(base + extra, 2)

    return [
        patient_id,
        dep_name_to_id[dep],
        bed,
        adm.strftime('%Y-%m-%d %H:%M:%S'),
        dis.strftime('%Y-%m-%d %H:%M:%S'),
        random.choice(icds),
        random.choice(icds),
        ken_code,
        f'{total:.2f}',
        f'{extra:.2f}',
    ]

def build_patient_profiles(patient_ids, departments):
    profiles = {}
    for patient_id in patient_ids:
        roll = random.random()
        if roll < 0.55:
            base_weight = 1.0
        elif roll < 0.80:
            base_weight = 1.7
        elif roll < 0.94:
            base_weight = 2.6
        else:
            base_weight = 3.8

        profiles[patient_id] = {
            'base_weight': base_weight,
            'home_department': random.choice(departments),
        }
    return profiles

def choose_patient(patient_ids, patient_profiles, patient_total_stays, patient_dep_stays, dep):
    weighted = []
    for patient_id in patient_ids:
        profile = patient_profiles[patient_id]
        total_stays = patient_total_stays[patient_id]
        same_dep_stays = patient_dep_stays[(patient_id, dep)]

        score = profile['base_weight']
        if profile['home_department'] == dep:
            score *= 2.1
        if same_dep_stays:
            score *= 1.35 + min(same_dep_stays, 3) * 0.15

        score /= (1 + 0.22 * total_stays)
        weighted.append(score)

    return random.choices(patient_ids, weights=weighted, k=1)[0]

def smooth_icd_category_counts(rows, icds):
    icds_by_letter = defaultdict(list)
    for code in icds:
        letter = clean(code)[:1]
        if letter:
            icds_by_letter[letter].append(code)

    counts = defaultdict(lambda: defaultdict(int))
    for row in rows:
        year = row[3][:4]
        letter = clean(row[5])[:1]
        if letter:
            counts[year][letter] += 1

    years = ('2025', '2026')
    letters = sorted(set(counts[years[0]]) | set(counts[years[1]]))

    for letter in letters:
        if min(counts[years[0]].get(letter, 0), counts[years[1]].get(letter, 0)) >= 5:
            if counts[years[0]].get(letter, 0) == counts[years[1]].get(letter, 0):
                return

    candidates = []
    for letter in letters:
        left = counts[years[0]].get(letter, 0)
        right = counts[years[1]].get(letter, 0)
        if min(left, right) >= 5 and left != right:
            candidates.append((abs(left - right), letter, left, right))
    if not candidates:
        return

    _, letter, left, right = min(candidates)
    donor_year = years[0] if left > right else years[1]
    receiver_year = years[1] if donor_year == years[0] else years[0]
    moves = abs(left - right)

    receiver_letter = None
    receiver_count = -1
    for candidate in letters:
        if candidate == letter or not icds_by_letter[candidate]:
            continue
        current = counts[donor_year].get(candidate, 0)
        if current > receiver_count:
            receiver_letter = candidate
            receiver_count = current
    if not receiver_letter:
        return

    donor_rows = []
    for idx, row in enumerate(rows):
        if row[3][:4] == donor_year and clean(row[5]).startswith(letter):
            donor_rows.append(idx)
            if len(donor_rows) == moves:
                break

    replacement_codes = icds_by_letter[receiver_letter]
    for offset, idx in enumerate(donor_rows):
        rows[idx][5] = replacement_codes[offset % len(replacement_codes)]

def main():
    random.seed(SEED)
    data = DATA_DIR

    patients = read_rows(find_file(data, 'patients.csv'))
    if not patients: die('patients.csv is empty')
    patient_ids = list(range(1, len(patients) + 1))

    deps = read_rows(find_file(data, 'departments.csv'))
    dep_name_to_id = {}
    for i, r in enumerate(deps, 1):
        dep_id = int(clean(r.get('department_id')) or i)
        name = clean(r.get('name') or r.get('department_name'))
        if name:
            dep_name_to_id[name] = dep_id
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

    next_free = {}
    all_beds = []
    for dep, beds in beds_by_dep.items():
        for bed in beds:
            next_free[(dep, bed)] = datetime.combine(start, time(0, 0))
            all_beds.append((dep, bed))
    if not all_beds: die('no beds available')

    out = []
    patient_profiles = build_patient_profiles(patient_ids, list(dep_name_to_id))
    patient_total_stays = defaultdict(int)
    patient_dep_stays = defaultdict(int)

    i = 0
    while len(out) < N:
        dep, bed = all_beds[i % len(all_beds)]
        ken_code, base, avg_los = random.choice(kens)
        stay_days = random.randint(1, max(2, min(10, avg_los + 2)))

        wanted = datetime.combine(
            start + timedelta(days=random.randint(0, max(0, total_days - 2))),
            time(random.choice([7,9,11,13,15,17]), 0)
        )

        adm = max(wanted, next_free[(dep, bed)] + timedelta(hours=1))
        hard_end = datetime.combine(end + timedelta(days=1), time(23, 0))
        if adm >= hard_end:
            i += 1
            continue

        dis = adm + timedelta(days=stay_days, hours=random.choice([8,10,12]))
        if dis > hard_end:
            dis = hard_end
        if dis <= adm:
            i += 1
            continue

        next_free[(dep, bed)] = dis

        patient_id = choose_patient(
            patient_ids,
            patient_profiles,
            patient_total_stays,
            patient_dep_stays,
            dep,
        )

        out.append(make_row(patient_id, dep, bed, adm, dis, dep_name_to_id, icds, kens))
        patient_total_stays[patient_id] += 1
        patient_dep_stays[(patient_id, dep)] += 1
        i += 1

    smooth_icd_category_counts(out, icds)

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, 'w', newline='', encoding='utf-8') as fp:
        w = csv.writer(fp)
        w.writerow(HOSP_COLS)
        w.writerows(out)

    print(f'Wrote {len(out)} rows to {OUT_PATH}')
    print('Hospitalizations now emerge from weighted patient reuse and department affinity.')

if __name__ == '__main__':
    main()
