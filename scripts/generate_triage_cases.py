import csv, random, glob
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
HOSPITALIZATIONS_PATH = DATA_DIR / 'hospitalizations.csv'
OUT_PATH = DATA_DIR / 'triage_cases.csv'
TOTAL = 2550
REFERRED = 1850
SEED = 43
YEAR_START = datetime(2025, 3, 20, 0, 0)
YEAR_END = datetime(2026, 3, 19, 23, 59)

STAFF_COLS = ['amka','first_name','last_name','age','email','phone','hire_date','staff_type']
NURSE_COLS = ['rank','department']

SYMPTOMS = [
    'Chest pain and shortness of breath',
    'Abdominal pain with nausea',
    'High fever and weakness',
    'Severe headache and dizziness',
    'Trauma after fall',
    'Persistent cough and breathing difficulty',
    'Acute allergic reaction symptoms',
    'Vomiting and dehydration',
    'Back pain with limited mobility',
    'Sudden neurological symptoms',
    'Postoperative complication symptoms',
    'Urinary pain and fever',
]

def die(msg):
    raise SystemExit('ERROR: ' + msg)

def clean(x):
    return str(x or '').strip()

def find(data, name):
    p = data / name
    if p.exists():
        return p
    hits = sorted(glob.glob(str(data / (name.replace('.csv','') + '*.csv'))))
    if hits:
        return Path(hits[0])
    die(f'missing {name}')

def read_rows(path, fallback=None):
    txt = path.read_text(encoding='utf-8-sig').splitlines()
    if not txt:
        return []
    first = [clean(x) for x in next(csv.reader([txt[0]]))]
    has_header = fallback is None or any(x in first for x in fallback)
    with path.open(encoding='utf-8-sig', newline='') as fp:
        if has_header:
            return [{clean(k): clean(v) for k, v in r.items()} for r in csv.DictReader(fp)]
        return [dict(zip(fallback, map(clean, r))) for r in csv.reader(fp)]

def load_deps(data):
    out = {}
    for i, r in enumerate(read_rows(find(data, 'departments.csv')), 1):
        name = clean(r.get('name') or r.get('department_name'))
        if name:
            out[name] = i
    if not out:
        die('no departments found')
    return out

def load_nurses(data, dep_ids):
    staff = read_rows(find(data, 'staff.csv'), STAFF_COLS)
    nurse_staff_ids = [i for i, r in enumerate(staff, 1) if clean(r.get('staff_type')).upper() == 'NURSE']
    nurse_rows = read_rows(find(data, 'nurse_department_rank.csv'), NURSE_COLS)
    by_dep = defaultdict(list)
    for staff_id, r in zip(nurse_staff_ids, nurse_rows):
        dep = clean(r.get('department'))
        if dep in dep_ids:
            by_dep[dep_ids[dep]].append(staff_id)
    all_nurses = [sid for xs in by_dep.values() for sid in xs]
    if not all_nurses:
        die('no nurses found')
    return by_dep, all_nurses

def rand_dt(start=YEAR_START, end=YEAR_END):
    seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, seconds))

def main():
    random.seed(SEED)
    data = DATA_DIR
    deps = load_deps(data)
    by_dep_nurses, all_nurses = load_nurses(data, deps)
    ed_dep_id = deps.get('Emergency Department')
    triage_pool = by_dep_nurses.get(ed_dep_id, []) or all_nurses

    hosp_path = HOSPITALIZATIONS_PATH
    if not hosp_path.exists():
        hosp_path = find(data, 'hospitalizations.csv')
    hosps = read_rows(hosp_path)
    if len(hosps) < REFERRED:
        die(f'hospitalizations.csv has {len(hosps)} rows, need at least {REFERRED}')

    patient_ids = sorted({int(clean(r.get('patient_id'))) for r in hosps if clean(r.get('patient_id')).isdigit()})
    if not patient_ids:
        patient_ids = list(range(1, 201))

    out = []

    # One referred triage case for each hospitalization row.
    # Assumes hospitalizations are loaded into an empty/truncated table, so ids are 1..N in CSV order.
    for hid, h in enumerate(hosps[:REFERRED], 1):
        pid = int(clean(h.get('patient_id')))
        dep_id = int(clean(h.get('department_id')))
        adm = datetime.fromisoformat(clean(h.get('admission_date')))
        arrival = adm - timedelta(hours=random.randint(1, 8), minutes=random.randint(0, 59))
        service = arrival + timedelta(minutes=random.randint(5, 90))
        if service > adm:
            service = adm - timedelta(minutes=random.randint(1, 20))
        nurse = random.choice(triage_pool)
        urgency = random.randint(1, 3)
        out.append([
            pid,
            nurse,
            arrival.strftime('%Y-%m-%d %H:%M:%S'),
            service.strftime('%Y-%m-%d %H:%M:%S'),
            random.choice(SYMPTOMS),
            urgency,
            'REFERRED_FOR_HOSPITALIZATION',
            dep_id,
            hid,
        ])

    # Extra discharged triage cases without hospitalization.
    extra = TOTAL - REFERRED
    for _ in range(extra):
        pid = random.choice(patient_ids)
        arrival = rand_dt()
        service = arrival + timedelta(minutes=random.randint(5, 180))
        nurse = random.choice(triage_pool)
        urgency = random.randint(3, 5)
        out.append([
            pid,
            nurse,
            arrival.strftime('%Y-%m-%d %H:%M:%S'),
            service.strftime('%Y-%m-%d %H:%M:%S'),
            random.choice(SYMPTOMS),
            urgency,
            'DISCHARGED_WITH_INSTRUCTIONS',
            '',
            '',
        ])

    random.shuffle(out)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open('w', encoding='utf-8', newline='') as fp:
        w = csv.writer(fp)
        w.writerow(['patient_id','triage_nurse_id','arrival_datetime','service_datetime','symptoms','urgency_level','outcome','referred_department_id','hospitalization_id'])
        w.writerows(out)
    print(f'Wrote {len(out)} rows to {OUT_PATH}')
    print(f'Referred: {REFERRED}, discharged: {extra}')

if __name__ == '__main__':
    main()
