#!/usr/bin/env bash
# pub_postclean.sh: final hardening pass on ~/laguna-bench-pub after export_pub.sh (2026-10-19).
# Drops full source-tree snapshots, env files and caches; scrubs every email (except noreply@anthropic.com / example/invalid domains).
set -euo pipefail; D=$HOME/laguna-bench-pub; cd $D
for t in $(find . -path ./.git -prune -o -type d -name tree -print); do
  rm -rf "$t"; echo "Full mem-mcp source snapshot used by the gate/scorer; omitted (see repo.diff)." > "$(dirname $t)/TREE-OMITTED.md"; done
find . -path ./.git -prune -o \( -name '*.env' -o -name 'run.env' -o -name '.mypy_cache' -o -name '__pycache__' -o -name '*.pem' -o -name 'cache.db' \) -print | grep -v '\.env\.example$' | xargs -r rm -rf
python3 - "$D" <<'PY'
import os,re,sys,gzip
R=sys.argv[1]; E=re.compile(rb'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}')
KEEP=(b'noreply@anthropic.com',b'@example.com',b'@example.org',b'.invalid')
def sub(b): return E.sub(lambda m: m.group(0) if any(k in m.group(0) for k in KEEP) else b'<email>', b)
n=0
for dp,dn,fn in os.walk(R):
    if '.git' in dp.split(os.sep): continue
    for f in fn:
        p=os.path.join(dp,f)
        if os.path.islink(p): continue
        try:
            if f.endswith('.gz'):
                raw=gzip.open(p).read(); new=sub(raw)
                if new!=raw: gzip.open(p,'wb').write(new); n+=1
            else:
                raw=open(p,'rb').read()
                if b'\0' in raw[:4096]: continue
                new=sub(raw)
                if new!=raw: open(p,'wb').write(new); n+=1
        except Exception as e: print('skip',p,e)
print('email-scrubbed files:',n)
PY
du -sh --exclude=.git .
