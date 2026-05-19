#!/usr/bin/env python3
import argparse, csv, glob
from collections import defaultdict, deque
from datetime import date, datetime, timedelta
from pathlib import Path

PER_SHIFT = 2
MONTH_LIMIT = 25
REST_HOURS = 8
MAX_NIGHTS = 3
STAFF_COLS = ['amka','first_name','last_name','age','email','phone','hire_date','staff_type']
ADMIN_COLS = ['role','office','department']

def die(s): raise SystemExit('INFEASIBLE INPUT / ERROR: ' + s)
def c(x): return str(x or '').strip()
def find(data, name):
    p = data / name
    if p.exists(): return p
    hits = sorted(glob.glob(str(data / (name.replace('.csv','') + '*.csv'))))
    if hits: return Path(hits[0])
    die(f'missing {name}')

def rows(path, fallback=None):
    txt = path.read_text(encoding='utf-8-sig').splitlines()
    if not txt: return []
    first = [c(x) for x in next(csv.reader([txt[0]]))]
    has_header = fallback is None or any(x in first for x in fallback)
    with path.open(encoding='utf-8-sig', newline='') as fp:
        if has_header:
            return [{c(k): c(v) for k, v in r.items()} for r in csv.DictReader(fp)]
        return [dict(zip(fallback, map(c, r))) for r in csv.reader(fp)]

def department_ids(data):
    out = {}
    for i, r in enumerate(rows(find(data, 'departments.csv')), 1):
        dep_id = c(r.get('department_id')) or str(i)
        name = c(r.get('name') or r.get('department_name'))
        out[dep_id] = name
    return out

def parse_dt(d, hm):
    h, m = map(int, hm.split(':'))
    return datetime(d.year, d.month, d.day, h, m)

def load_shifts(data, id2dep, start=None, end=None):
    ans = []
    for r in rows(find(data, 'duty_shifts.csv')):
        d = date.fromisoformat(c(r.get('shift_date') or r.get('date')))
        if start and d < start: continue
        if end and d > end: continue
        dep = c(r.get('department_name') or r.get('department')) or id2dep.get(c(r.get('department_id')), '')
        st = parse_dt(d, c(r.get('start_time'))); en = parse_dt(d, c(r.get('end_time')))
        if en <= st: en += timedelta(days=1)
        ans.append({'dep': dep, 'date': d, 'type': c(r.get('shift_type')), 'start': st, 'end': en})
    return sorted(ans, key=lambda x: (x['start'], x['dep'], x['type']))

def load_admins(data):
    staff_admins = [r for r in rows(find(data, 'staff.csv'), STAFF_COLS) if c(r.get('staff_type')).upper() == 'ADMINISTRATIVE']
    role_rows = rows(find(data, 'administrative_department_roles.csv'), ADMIN_COLS)
    if len(staff_admins) < len(role_rows):
        die(f'staff.csv has {len(staff_admins)} ADMINISTRATIVE rows but administrative_department_roles.csv has {len(role_rows)} rows')
    bydep = defaultdict(deque)
    # load.sql-style assumption: admin role rows match ADMINISTRATIVE staff rows by order
    for s, r in zip(staff_admins, role_rows):
        dep = c(r.get('department') or r.get('department_name'))
        amka = c(s.get('amka'))
        if dep and amka: bydep[dep].append(amka)
    return bydep

def mon(d): return (d.year, d.month)
def can(a, s, count, last_end, nights):
    if count[(a, mon(s['date']))] >= MONTH_LIMIT: return False
    if a in last_end and (s['start'] - last_end[a]).total_seconds() < REST_HOURS * 3600: return False
    if s['type'] == 'NIGHT' and all((s['date'] - timedelta(days=i)) in nights[a] for i in range(1, MAX_NIGHTS + 1)):
        return False
    return True

def pick(q, s, count, last_end, nights):
    chosen = []
    for _ in range(len(q)):
        a = q.popleft(); q.append(a)
        if a not in chosen and can(a, s, count, last_end, nights):
            chosen.append(a)
            if len(chosen) == PER_SHIFT: break
    return chosen

def capacity_check(bydep, shifts):
    need = defaultdict(int)
    for s in shifts: need[(s['dep'], mon(s['date']))] += PER_SHIFT
    for (dep, m), n in sorted(need.items()):
        have = len(bydep.get(dep, [])) * MONTH_LIMIT
        if have < n:
            short = n - have
            add = (short + MONTH_LIMIT - 1) // MONTH_LIMIT
            die(f'{dep} in {m[0]}-{m[1]:02d} needs {n} admin assignments, has capacity {have}. Add {add} ADMINISTRATIVE staff for this department')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data-dir', default='data')
    ap.add_argument('--out', default='data/admin_shift_assignments_by_amka.csv')
    ap.add_argument('--start-date')
    ap.add_argument('--end-date')
    a = ap.parse_args(); data = Path(a.data_dir)
    start = date.fromisoformat(a.start_date) if a.start_date else None
    end = date.fromisoformat(a.end_date) if a.end_date else None

    shifts = load_shifts(data, department_ids(data), start, end)
    bydep = load_admins(data)
    capacity_check(bydep, shifts)

    count, last_end, nights, out = defaultdict(int), {}, defaultdict(set), []
    for s in shifts:
        q = bydep.get(s['dep'], deque())
        if len(q) < PER_SHIFT: die(f'{s["dep"]} has fewer than {PER_SHIFT} admins')
        chosen = pick(q, s, count, last_end, nights)
        if len(chosen) < PER_SHIFT:
            info = [(x, count[(x, mon(s['date']))]) for x in list(q)[:20]]
            die(f'cannot fill {s["dep"]} {s["date"]} {s["type"]}. Local admins/month counts: {info}')
        for admin_amka in chosen:
            count[(admin_amka, mon(s['date']))] += 1
            last_end[admin_amka] = s['end']
            if s['type'] == 'NIGHT': nights[admin_amka].add(s['date'])
            out.append([s['type'], s['dep'], s['date'].isoformat(), admin_amka])

    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    with open(a.out, 'w', newline='', encoding='utf-8') as fp:
        w = csv.writer(fp)
        w.writerow(['shift_type', 'department_name', 'date', 'admin_amka'])
        w.writerows(out)
    print(f'Wrote {len(out)} rows to {a.out}')

if __name__ == '__main__':
    main()
