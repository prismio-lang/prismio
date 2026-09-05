import subprocess, statistics, random, re, os, json, sys
W='build/kvhash'
env=dict(os.environ); env['PATH']='/opt/homebrew/opt/llvm/bin:'+env.get('PATH','')
names=[b['name'] for b in json.load(open('benchmarks/benchmarks.json'))['benchmarks'] if b['status']=='implemented']

if sys.argv[1]=='verify':
    rep={}
    for n in names:
        rep[n]={}
        for a in ('before','after'):
            r=subprocess.run([f'{W}/{a}-verify',n,f'{W}/input.txt',f'{W}/{a}.out'],capture_output=True,text=True,env=env)
            t=r.stdout+r.stderr
            m=re.search(r'aif-verify: (\d+) allocated, (\d+) released, (\d+) leaked, (\d+) violation',t)
            c=re.search(r'result: (-?\d+)',t)
            mem=re.search(r'(\d+) peak live bytes',t)
            rep[n][a]=dict(zip(('allocated','released','leaked','violations'),map(int,m.groups())))
            rep[n][a]['checksum']=c.group(1); rep[n][a]['peak']=int(mem.group(1)) if mem else 0
    bad=[(n,v) for n,v in rep.items() if v['before']['checksum']!=v['after']['checksum']
         or v['before']['violations'] or v['after']['violations']
         or v['before']['leaked']!=2 or v['after']['leaked']!=2]
    json.dump(rep, open('aif/evidence/kv-adaptive-hash-2026-09-06/verification.json','w'), indent=2)
    print('benchmarks:',len(rep))
    print('checksum/violation/leak anomalies:', bad if bad else 'none')
    alloc=[(n,v['before']['allocated'],v['after']['allocated']) for n,v in rep.items() if v['before']['allocated']!=v['after']['allocated']]
    print('allocation-count changes:', alloc if alloc else 'none')
    peak=[(n,v['before']['peak'],v['after']['peak']) for n,v in rep.items() if v['before']['peak']!=v['after']['peak']]
    print('peak-live-byte changes:', peak if peak else 'none')
    sys.exit(0)

arms={'before':f'{W}/before-suite','after':f'{W}/after-suite','repeat':f'{W}/before-suite'}
rng=random.Random(90909); out={}
print(f"{'benchmark':24}{'before':>10}{'after':>10}{'ratio':>8}{'noise':>8}")
for n in names:
    s={a:[] for a in arms}; sums=set()
    for it in range(6+25):
        o=list(arms); rng.shuffle(o)
        for a in o:
            r=subprocess.run([arms[a],n,f'{W}/input.txt',f'{W}/{a}.out'],capture_output=True,text=True,env=env)
            f=dict(l.split(': ',1) for l in r.stdout.splitlines() if ': ' in l)
            sums.add(f['result'])
            if it>=6: s[a].append(int(f['elapsed_ns']))
    assert len(sums)==1,(n,sums)
    med={a:statistics.median(v) for a,v in s.items()}
    out[n]=med
    print(f"{n:24}{med['before']/1e6:10.3f}{med['after']/1e6:10.3f}{med['after']/med['before']:8.3f}{med['repeat']/med['before']:8.3f}", flush=True)
json.dump(out, open('aif/evidence/kv-adaptive-hash-2026-09-06/timings.json','w'), indent=2)
