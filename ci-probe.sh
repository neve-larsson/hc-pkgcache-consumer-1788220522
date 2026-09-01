#!/bin/bash
set -euo pipefail
python3 - <<'PY'
import pathlib,hashlib,tarfile,io,json
root=pathlib.Path.home()/'.npm'
target='0de4d53f5bf7d7a23d76932752b54cbd0b23712b28b258696b8fbe668b099b06'
marker_hash='9ed76c23fbb1516e4afeae78a5913e3cdea697ae349011187d6032de21d08c44'
hits=[]
for p in root.rglob('*'):
 if not p.is_file():continue
 try:
  if p.stat().st_size!=435:continue
  body=p.read_bytes();digest=hashlib.sha256(body).hexdigest()
 except:continue
 if digest!=target:continue
 marker=False
 try:
  with tarfile.open(fileobj=io.BytesIO(body),mode='r:gz') as tf:
   marker=hashlib.sha256(tf.extractfile('package/secret.txt').read()).hexdigest()==marker_hash
 except:pass
 hits.append({'relative_path':str(p.relative_to(root)),'bytes':len(body),'sha256':digest,'private_marker_match':marker})
print('OFFLINE_CACHE_CONTENT',json.dumps({'network_requests_to_package_hosts':0,'matches':hits}))
if not hits or not all(x['private_marker_match'] for x in hits):raise SystemExit('private tarball content not found in restored cache')
PY
