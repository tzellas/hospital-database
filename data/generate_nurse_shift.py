#!/usr/bin/env python3
import csv
import glob
from collections import defaultdict, deque
from datetime import date, datetime, timedelta
from pathlib import Path

PER_SHIFT = 6
MONTH_LIMIT = 20
REST_HOURS = 8
MAX_NIGHTS = 3
DATA_DIR = Path('data')
OUT_PATH = DATA_DIR / 'nurse_shift_assignments_by_amka.csv'
START_DATE = None
END_DATE = None
STAFF_COLS = ['amka','first_name','last_name','age','email','phone','hire_date','staff_type']
NURSE_COLS = ['rank','department']

def die(s): raise SystemExit('INFEASIBLE INPUT / ERROR: ' + s)
def c(x): return str(x or '').strip()
def f(data, name):
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

def dep_map(data):
    out = {}
    for i, r in enumerate(rows(f(data,'departments.csv')), 1):
        out[c(r.get('department_id')) or str(i)] = c(r.get('name') or r.get('department_name'))
    return out

def dt(d, hm):
    h, m = map(int, hm.split(':'))
    return datetime(d.year, d.month, d.day, h, m)

def load_shifts(data, id2dep, start=None, end=None):
    ans = []
    for r in rows(f(data,'duty_shifts.csv')):
        d = date.fromisoformat(c(r.get('shift_date') or r.get('date')))
        if start and d < start: continue
        if end and d > end: continue
        dep = c(r.get('department_name') or r.get('department')) or id2dep.get(c(r.get('department_id')), '')
        st = dt(d, c(r.get('start_time'))); en = dt(d, c(r.get('end_time')))
        if en <= st: en += timedelta(days=1)
        ans.append({'dep':dep,'date':d,'type':c(r.get('shift_type')),'start':st,'end':en})
    return sorted(ans, key=lambda x:(x['start'], x['dep'], x['type']))

def load_nurses(data):
    staff = rows(f(data,'staff.csv'), STAFF_COLS)
    nurse_amkas = [c(r.get('amka')) for r in staff if c(r.get('staff_type')).upper() == 'NURSE']
    nr = rows(f(data,'nurse_department_rank.csv'), NURSE_COLS)
    if len(nr) > len(nurse_amkas): die('more nurse_department_rank rows than NURSE staff rows')
    nurses = []
    for amka, r in zip(nurse_amkas, nr):
        dep = c(r.get('department') or r.get('department_name'))
        if dep: nurses.append({'id':amka, 'dep':dep})
    return nurses

def mon(d): return (d.year, d.month)
def can(n, s, count, last_end, nights):
    if count[(n['id'], mon(s['date']))] >= MONTH_LIMIT: return False
    if n['id'] in last_end and (s['start'] - last_end[n['id']]).total_seconds() < REST_HOURS*3600: return False
    if s['type'] == 'NIGHT' and all((s['date'] - timedelta(days=i)) in nights[n['id']] for i in range(1, MAX_NIGHTS+1)): return False
    return True

def main():
    data = DATA_DIR
    start = date.fromisoformat(START_DATE) if START_DATE else None
    end = date.fromisoformat(END_DATE) if END_DATE else None

    shifts = load_shifts(data, dep_map(data), start, end)
    nurses = load_nurses(data)
    bydep = defaultdict(deque)
    for n in nurses: bydep[n['dep']].append(n)

    needed = defaultdict(int)
    for s in shifts: needed[(s['dep'], mon(s['date']))] += PER_SHIFT
    for (dep, m), need in needed.items():
        cap = len(bydep[dep]) * MONTH_LIMIT
        if need > cap: die(f'{dep} in {m[0]}-{m[1]:02d} needs {need}, capacity is {cap}; add {((need+MONTH_LIMIT-1)//MONTH_LIMIT)-len(bydep[dep])} nurses')

    count, last_end, nights, out = defaultdict(int), {}, defaultdict(set), []
    for s in shifts:
        q = bydep[s['dep']]
        if len(q) < PER_SHIFT: die(f'{s[dep]} has fewer than {PER_SHIFT} nurses')
        chosen, seen = [], len(q)
        for _ in range(seen):
            n = q.popleft(); q.append(n)
            if n['id'] not in {x['id'] for x in chosen} and can(n, s, count, last_end, nights):
                chosen.append(n)
                if len(chosen) == PER_SHIFT: break
        if len(chosen) < PER_SHIFT:
            die(f"cannot fill {s['dep']} {s['date']} {s['type']} with rest/month/night constraints")
        for n in chosen:
            count[(n['id'], mon(s['date']))] += 1
            last_end[n['id']] = s['end']
            if s['type'] == 'NIGHT': nights[n['id']].add(s['date'])
            out.append([s['type'], s['dep'], s['date'].isoformat(), n['id']])

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, 'w', newline='', encoding='utf-8') as fp:
        w = csv.writer(fp); w.writerow(['shift_type','department_name','date','nurse_amka']); w.writerows(out)
    print(f'Wrote {len(out)} rows to {OUT_PATH}')

if __name__ == '__main__': main()
