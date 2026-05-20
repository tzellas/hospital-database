#!/usr/bin/env python3
import csv
import glob
import itertools
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

PER_SHIFT=3; MONTH_LIMIT=15; REST_HOURS=8; MAX_NIGHTS=3
SENIOR={'CONSULTANT_A','DIRECTOR'}
DATA_DIR = Path('data')
OUT_PATH = DATA_DIR / 'doctor_shift_assignments_by_license.csv'
START_DATE = None
END_DATE = None
STAFF_COLS=['amka','first_name','last_name','age','email','phone','hire_date','staff_type']
DOC_COLS=['medical_license_num','specialty','rank']
DIR_COLS=['staff_id','medical_license_num','specialty','rank','supervisor_doc_id']

def die(s): raise SystemExit('INFEASIBLE INPUT / ERROR: '+s)
def c(x): return str(x or '').strip()
def find(data,name,optional=False):
    p=data/name
    if p.exists(): return p
    hits=sorted(glob.glob(str(data/(name.replace('.csv','')+'*.csv'))))
    if hits: return Path(hits[0])
    if optional: return None
    die('missing '+name)
def read(path, fallback=None):
    if path is None: return []
    lines=path.read_text(encoding='utf-8-sig').splitlines()
    if not lines: return []
    first=[c(x) for x in next(csv.reader([lines[0]]))]
    has_header = fallback is None or any(x in first for x in fallback)
    with path.open(encoding='utf-8-sig', newline='') as fp:
        if has_header: return [{c(k):c(v) for k,v in r.items()} for r in csv.DictReader(fp)]
        return [dict(zip(fallback,map(c,r))) for r in csv.reader(fp)]
def ym(d): return (d.year,d.month)
def dt(d,hm):
    h,m=map(int,hm.split(':')); return datetime(d.year,d.month,d.day,h,m)

def load_departments(data):
    id2, manager2 = {}, {}
    for i,r in enumerate(read(find(data,'departments.csv')),1):
        dep_id=c(r.get('department_id')) or str(i)
        name=c(r.get('name') or r.get('department_name'))
        manager=c(r.get('manager_id'))
        if name: id2[dep_id]=name
        if name and manager: manager2[manager]=name
    return id2, manager2

def load_map(data):
    spec2deps=defaultdict(set)
    for r in read(find(data,'dept_specialty_map.csv')):
        dep=c(r.get('department_name') or r.get('department')); spec=c(r.get('specialty'))
        if dep and spec: spec2deps[spec].add(dep)
    if not spec2deps: die('empty dept_specialty_map.csv')
    return spec2deps

def load_shifts(data,id2,start=None,end=None):
    ans=[]
    for r in read(find(data,'duty_shifts.csv')):
        d=date.fromisoformat(c(r.get('shift_date') or r.get('date')))
        if start and d<start: continue
        if end and d>end: continue
        dep=c(r.get('department_name') or r.get('department')) or id2.get(c(r.get('department_id')),'')
        st=dt(d,c(r.get('start_time'))); en=dt(d,c(r.get('end_time')))
        if en<=st: en+=timedelta(days=1)
        ans.append({'dep':dep,'date':d,'type':c(r.get('shift_type')),'start':st,'end':en})
    return sorted(ans,key=lambda s:(s['date'],s['dep'],s['start']))

def load_doctors(data,manager2,spec2deps):
    staff=read(find(data,'staff.csv'),STAFF_COLS)
    doctor_staff=[str(i) for i,r in enumerate(staff,1) if c(r.get('staff_type')).upper()=='DOCTOR']
    used=set(); docs=[]
    for r in read(find(data,'directors.csv',optional=True),DIR_COLS):
        sid,lic,spec=c(r.get('staff_id')),c(r.get('medical_license_num')),c(r.get('specialty'))
        if not (sid and lic and spec): continue
        used.add(sid)
        possible=[manager2[sid]] if sid in manager2 else sorted(spec2deps.get(spec,[]))
        if possible: docs.append({'id':lic,'spec':spec,'rank':'DIRECTOR','possible':possible})
    free=[sid for sid in doctor_staff if sid not in used]
    for sid,r in zip(free, read(find(data,'doctors.csv'),DOC_COLS)):
        lic,spec,rank=c(r.get('medical_license_num')),c(r.get('specialty')),c(r.get('rank'))
        possible=sorted(spec2deps.get(spec,[]))
        if lic and spec and rank and possible: docs.append({'id':lic,'spec':spec,'rank':rank,'possible':possible})
    return list({d['id']:d for d in docs}.values())

def required(shifts):
    req=defaultdict(int)
    for s in shifts: req[(s['dep'],ym(s['date']))]+=PER_SHIFT
    return req

def assign_local(docs,shifts):
    need=defaultdict(int)
    for (dep,_),slots in required(shifts).items(): need[dep]+=slots
    bydep=defaultdict(list)
    # doctors with fewer options first; directors first when fixed
    docs=sorted(docs,key=lambda d:(0 if d['rank']=='DIRECTOR' and len(d['possible'])==1 else 1, len(d['possible']), d['id']))
    for d in docs:
        choices=[x for x in d['possible'] if x]
        if not choices: continue
        dep=choices[0] if d['rank']=='DIRECTOR' and len(choices)==1 else max(choices,key=lambda x:need[x])
        bydep[dep].append(d); need[dep]-=MONTH_LIMIT
    return bydep

def can(d,s,count,last_end,nights):
    if count[(d['id'],ym(s['date']))] >= MONTH_LIMIT: return False
    if d['id'] in last_end and (s['start']-last_end[d['id']]).total_seconds() < REST_HOURS*3600: return False
    if s['type']=='NIGHT' and all((s['date']-timedelta(days=i)) in nights[d['id']] for i in range(1,MAX_NIGHTS+1)): return False
    return True

def valid_combo(combo):
    return (not any(d['rank']=='RESIDENT' for d in combo)) or any(d['rank'] in SENIOR for d in combo)

def pick(cands,s,count,last_end,nights):
    avail=[d for d in cands if can(d,s,count,last_end,nights)]
    if len(avail)<PER_SHIFT: return []
    best=None; best_score=None
    for combo in itertools.combinations(avail,PER_SHIFT):
        if not valid_combo(combo): continue
        senior_n=sum(d['rank'] in SENIOR for d in combo)
        resident_n=sum(d['rank']=='RESIDENT' for d in combo)
        # Lower score is better: avoid residents when possible, preserve seniors, balance monthly load.
        loads=[count[(d['id'],ym(s['date']))] for d in combo]
        score=(sum(loads), max(loads), senior_n, resident_n, tuple(d['id'] for d in combo))
        if best is None or score<best_score:
            best=list(combo); best_score=score
    return best or []

def capacity_check(bydep,shifts):
    req=required(shifts)
    for (dep,mon),slots in sorted(req.items()):
        docs=bydep.get(dep,[]); cap=len(docs)*MONTH_LIMIT
        nonres=sum(d['rank']!='RESIDENT' for d in docs); seniors=sum(d['rank'] in SENIOR for d in docs)
        if len(docs)<PER_SHIFT: die(f'{dep}: add {PER_SHIFT-len(docs)} doctors')
        if cap<slots: die(f'{dep} {mon[0]}-{mon[1]:02d}: add {(slots-cap+MONTH_LIMIT-1)//MONTH_LIMIT} doctors; needs {slots}, capacity {cap}')
        # Adjacent 8h shifts need at least 6 usable doctors to alternate MORNING/EVENING.
        if len(docs)<6: die(f'{dep}: add {6-len(docs)} doctors for 8h rest rotation')
        if seniors<1 and nonres<PER_SHIFT: die(f'{dep}: add at least 1 CONSULTANT_A/DIRECTOR or enough non-resident doctors')

def main():
    data = DATA_DIR
    start = date.fromisoformat(START_DATE) if START_DATE else None
    end = date.fromisoformat(END_DATE) if END_DATE else None
    id2,manager2=load_departments(data)
    shifts=load_shifts(data,id2,start,end)
    bydep=assign_local(load_doctors(data,manager2,load_map(data)),shifts)
    capacity_check(bydep,shifts)
    counts,last_end,nights,out=defaultdict(int),{},defaultdict(set),[]
    for s in shifts:
        chosen=pick(bydep.get(s['dep'],[]),s,counts,last_end,nights)
        if not chosen:
            status=sorted((d['id'],d['rank'],counts[(d['id'],ym(s['date']))]) for d in bydep.get(s['dep'],[]))
            die(f"cannot fill {s['dep']} {s['date']} {s['type']}. Local doctors/month counts: {status}")
        for d in chosen:
            counts[(d['id'],ym(s['date']))]+=1
            last_end[d['id']]=s['end']
            if s['type']=='NIGHT': nights[d['id']].add(s['date'])
            out.append([s['type'],s['dep'],s['date'].isoformat(),d['id']])
    OUT_PATH.parent.mkdir(parents=True,exist_ok=True)
    with open(OUT_PATH,'w',encoding='utf-8',newline='') as fp:
        w=csv.writer(fp); w.writerow(['shift_type','department_name','date','medical_license_num']); w.writerows(out)
    print(f'Wrote {len(out)} rows to {OUT_PATH}')
if __name__=='__main__': main()
