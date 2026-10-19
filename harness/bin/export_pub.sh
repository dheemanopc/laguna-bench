#!/bin/bash
set -euo pipefail

# Export script for laguna-bench → laguna-bench-pub
# Creates a curated, scrubbed, re-runnable public copy
# Usage: ./bin/export_pub.sh

BENCH_DIR="~/laguna-bench"
PUB_DIR="~/laguna-bench-pub"

# Initialize destination, preserve .git
if [[ ! -d "$PUB_DIR" ]]; then
    mkdir -p "$PUB_DIR"
    git -C "$PUB_DIR" init -b main >/dev/null 2>&1 || true
else
    # Keep .git, remove everything else
    if [[ -d "$PUB_DIR/.git" ]]; then
        find "$PUB_DIR" -maxdepth 1 -type d ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
        find "$PUB_DIR" -maxdepth 1 -type f -exec rm {} + 2>/dev/null || true
    fi
fi

log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }

# === MAIN EXPORT ===

log "Exporting to $PUB_DIR"

# 1. harness/bin
log "→ harness/bin"
mkdir -p "$PUB_DIR/harness/bin"
rsync -a --delete \
    --exclude '*.pid' \
    --exclude '__pycache__' \
    --exclude '.pyc' \
    "$BENCH_DIR/bin/" "$PUB_DIR/harness/bin/" 2>/dev/null || true

# 2. harness/templates
log "→ harness/templates"
[[ -d "$BENCH_DIR/templates" ]] && {
    mkdir -p "$PUB_DIR/harness/templates"
    rsync -a --delete "$BENCH_DIR/templates/" "$PUB_DIR/harness/templates/" 2>/dev/null || true
}

# 3. harness/tasks
log "→ harness/tasks"
[[ -d "$BENCH_DIR/tasks" ]] && {
    mkdir -p "$PUB_DIR/harness/tasks"
    rsync -a --delete "$BENCH_DIR/tasks/" "$PUB_DIR/harness/tasks/" 2>/dev/null || true
}

if [[ -d "$BENCH_DIR/tasks/hidden" ]]; then
    mkdir -p "$PUB_DIR/harness/hidden"
    cp -r "$BENCH_DIR/tasks/hidden"/* "$PUB_DIR/harness/hidden/" 2>/dev/null || true
fi

# 4. docs/source
log "→ docs/source"
mkdir -p "$PUB_DIR/docs/source"
[[ -d "$BENCH_DIR/docs" ]] && {
    rsync -a --delete \
        --exclude '.git' \
        "$BENCH_DIR/docs/" "$PUB_DIR/docs/source/" 2>/dev/null || true
}

# Copy metadata docs
for file in STATE.md REPORT.md REPORT-BF16-2026-10-19.md HANDOFF-BF16.md bench-CLAUDE.md litellm.yaml; do
    [[ -f "$BENCH_DIR/$file" ]] && cp "$BENCH_DIR/$file" "$PUB_DIR/docs/source/" || true
done

# Copy known-red and baseline lists
for pattern in "known-red-*.txt" "baseline-*.txt"; do
    for file in $BENCH_DIR/$pattern; do
        [[ -f "$file" ]] && cp "$file" "$PUB_DIR/docs/source/" || true
    done
done

# 5. modelcard
log "→ modelcard"
[[ -d "$BENCH_DIR/modelcard" ]] && {
    mkdir -p "$PUB_DIR/modelcard"
    rsync -a --delete "$BENCH_DIR/modelcard/" "$PUB_DIR/modelcard/" 2>/dev/null || true
}

# 6. results
log "→ results"
mkdir -p "$PUB_DIR/results"
if [[ -d "$BENCH_DIR/results" ]]; then
    rsync -a --delete \
        --exclude '.git' \
        --exclude '*.pid' \
        "$BENCH_DIR/results/" "$PUB_DIR/results/" 2>/dev/null || true
fi

# 7. boxlogs - TEXT FILES ONLY (no venv, hf, models, .so)
log "→ boxlogs (text only, max depth 2)"
for boxdir in "$BENCH_DIR"/boxlogs-*/; do
    [[ ! -d "$boxdir" ]] && continue
    name=$(basename "$boxdir")
    log "  $name"
    mkdir -p "$PUB_DIR/boxlogs/$name"

    # Copy only text/log files, max depth 2, exclude large dirs
    find "$boxdir" -maxdepth 2 \
        -type f \( -name '*.log' -o -name '*.txt' -o -name '*.env' -o -name '*.json' -o -name '*.md' -o -name '*.out' -o -name '*.csv' -o -name 'status' \) \
        ! -path '*/conv/*' \
        ! -path '*/hf/*' \
        ! -path '*/venv/*' \
        ! -path '*/site-packages/*' \
        ! -name '*.so' \
        2>/dev/null | \
    while read -r file; do
        relpath="${file#$boxdir/}"
        mkdir -p "$PUB_DIR/boxlogs/$name/$(dirname "$relpath")"
        cp "$file" "$PUB_DIR/boxlogs/$name/$relpath" 2>/dev/null || true
    done
done

# 8. runs - FLATTEN runs/runs/<id> to runs/<id>, exclude score/out/tree
log "→ runs (flattened layout)"
mkdir -p "$PUB_DIR/runs"

# Handle main runs directory
if [[ -d "$BENCH_DIR/runs" ]]; then
    for rundir in "$BENCH_DIR/runs"/*/; do
        [[ ! -d "$rundir" ]] && continue
        runname=$(basename "$rundir")

        # Copy run artifacts, exclude repo and unwanted dirs
        mkdir -p "$PUB_DIR/runs/$runname"
        rsync -a --delete \
            --exclude 'repo' \
            --exclude 'score/out/tree' \
            --exclude '*.pid' \
            --exclude 'pgsock' \
            --exclude 'node_modules' \
            --exclude '.git' \
            "$rundir/" "$PUB_DIR/runs/$runname/" 2>/dev/null || true

        # Handle repo subdirectory if exists
        if [[ -d "$rundir/repo/.git" ]]; then
            base="HEAD~20"
            [[ -f "$rundir/.baseline_sha" ]] && base=$(cat "$rundir/.baseline_sha")
            git -C "$rundir/repo" log --stat --format='%h %ad %s' --date=iso "$base..HEAD" > "$PUB_DIR/runs/$runname/repo-log.txt" 2>/dev/null || \
                echo "Git log unavailable" > "$PUB_DIR/runs/$runname/repo-log.txt"
            git -C "$rundir/repo" diff "$base..HEAD" > "$PUB_DIR/runs/$runname/repo.diff" 2>/dev/null || \
                echo "Git diff unavailable" > "$PUB_DIR/runs/$runname/repo.diff"
            if ! git -C "$rundir/repo" diff --quiet 2>/dev/null; then
                git -C "$rundir/repo" diff > "$PUB_DIR/runs/$runname/repo-uncommitted.diff" 2>/dev/null || true
            fi
        fi

        # Convert run.env to run.env.example (scrub passwords)
        if [[ -f "$PUB_DIR/runs/$runname/run.env" ]]; then
            sed 's|://[^@]*@|://user:***@|g; s|=[^=]*$|=***|g' "$PUB_DIR/runs/$runname/run.env" > "$PUB_DIR/runs/$runname/run.env.example"
            rm "$PUB_DIR/runs/$runname/run.env"
        fi

        # Replace score/out/tree with marker
        if [[ -d "$PUB_DIR/runs/$runname/score/out/tree" ]]; then
            rm -rf "$PUB_DIR/runs/$runname/score/out/tree"
            mkdir -p "$PUB_DIR/runs/$runname/score/out"
            echo "This directory was a full source tree snapshot and has been omitted." > "$PUB_DIR/runs/$runname/score/out/TREE-OMITTED.md"
        fi
    done
fi

# Handle runs-T6-X1 and other misc runs → runs/_misc/
mkdir -p "$PUB_DIR/runs/_misc"
for rundir in "$BENCH_DIR"/runs-*/; do
    [[ ! -d "$rundir" ]] && continue
    runname=$(basename "$rundir")
    mkdir -p "$PUB_DIR/runs/_misc/$runname"
    rsync -a --delete \
        --exclude 'repo' \
        --exclude 'score/out/tree' \
        --exclude '*.pid' \
        --exclude 'pgsock' \
        "$rundir/" "$PUB_DIR/runs/_misc/$runname/" 2>/dev/null || true
done

# 9. config examples
log "→ config examples"
mkdir -p "$PUB_DIR/config"
if [[ -f "$BENCH_DIR/config/ssh_config" ]]; then
    sed 's/^\s*\([A-Za-z_]*\)\s\+.*/\1 <placeholder>/' "$BENCH_DIR/config/ssh_config" > "$PUB_DIR/config/ssh_config.example"
fi
if [[ -f "$BENCH_DIR/config/instance.env" ]]; then
    sed 's/^\([^=]*\)=.*/\1=<placeholder>/' "$BENCH_DIR/config/instance.env" > "$PUB_DIR/config/instance.env.example"
fi

# 10. Scrub sensitive data - COMPREHENSIVE WITH EMAIL AND TOKEN SCRUBBING
log "Scrubbing sensitive data (paths, emails, tokens)..."

# Use Python to handle all scrubbing including .gz files
python3 << 'SCRUB_EOF'
import os, re, gzip, sys
from pathlib import Path

pub_dir = Path('~/laguna-bench-pub')

# Email pattern and keep list
email_pattern = re.compile(
    r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
    re.IGNORECASE
)
keep_emails = {'noreply@anthropic.com'}
keep_domains = {'example.com', 'example.org'}

token_patterns = [
    (r'sk-[A-Za-z0-9]{40,}', '<redacted>'),
    (r'AKIA[0-9A-Z]{16,}', '<redacted>'),
    (r'ghp_[A-Za-z0-9]{36,}', '<redacted>'),
    (r'github_pat_[A-Za-z0-9_]{36,}', '<redacted>'),
    (r'xox[bp]-[A-Za-z0-9-]{40,}', '<redacted>'),
]

def scrub_email(text):
    def replace_email(match):
        email = match.group(1).lower()
        if email in keep_emails:
            return email
        domain = email.split('@')[1] if '@' in email else ''
        if domain in keep_domains:
            return email
        return '<email>'
    return email_pattern.sub(replace_email, text)

def scrub_text(text):
    text = text.replace('~', '~')
    text = scrub_email(text)
    for pattern, repl in token_patterns:
        text = re.sub(pattern, repl, text)
    return text

def process_file(filepath):
    try:
        if filepath.endswith('.gz'):
            try:
                with gzip.open(filepath, 'rt', errors='ignore') as f:
                    content = f.read()
                content = scrub_text(content)
                with gzip.open(filepath, 'wt') as f:
                    f.write(content)
                return True
            except:
                return False
        elif filepath.endswith(('.sh', '.py', '.md', '.txt', '.log', '.yaml', '.yml', '.json', '.jsonl', '.csv', '.env', '.example', '.out')):
            try:
                with open(filepath, 'r', errors='ignore') as f:
                    content = f.read()
                content = scrub_text(content)
                with open(filepath, 'w') as f:
                    f.write(content)
                return True
            except:
                return False
    except:
        pass
    return False

count = 0
for root, dirs, files in os.walk(pub_dir):
    if '.git' in root:
        continue
    for file in files:
        filepath = os.path.join(root, file)
        if process_file(filepath):
            count += 1

print(f"Scrubbed {count} files", file=sys.stderr)
SCRUB_EOF

log "Scrubbing complete"

# 11. Clean up environment variable files with secrets in boxlogs
log "Cleaning boxlog .env files with secrets..."
find "$PUB_DIR/boxlogs" -name "*.env" -type f 2>/dev/null | while read -r envfile; do
    if grep -qi "key\|token\|secret\|password\|Bearer" "$envfile" 2>/dev/null; then
        rm "$envfile"
    fi
done

# 12. Size reduction - gzip large text files (≥1MB)
log "Reducing size - gzipping large text files (≥1MB)..."
find "$PUB_DIR" -type f \( -name '*.log' -o -name '*.txt' -o -name '*.json' -o -name '*.csv' \) \
    ! -name '*.gz' ! -path '*/.git/*' 2>/dev/null | \
    while read -r file; do
        size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
        if (( size_bytes >= 1048576 )); then
            if gzip -9 "$file" 2>/dev/null; then
                :
            fi
        fi
    done

# === FINAL VERIFICATION ===

log "Running final verification scan..."
echo ""
echo "=== SECURITY VERIFICATION ==="

# Email check in text files
email_count=$(find "$PUB_DIR" -type f ! -path '*/.git/*' ! -name '*.gz' \
    -exec grep -hoE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' {} \; 2>/dev/null | \
    grep -v 'noreply@anthropic.com' | grep -v '@example\.\(com\|org\)' | sort -u | wc -l)
echo "Unredacted emails in text files: $email_count"

# Email check in gzip files
gz_email_count=$(find "$PUB_DIR" -type f ! -path '*/.git/*' -name '*.gz' \
    -exec zgrep -hoE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' {} \; 2>/dev/null | \
    grep -v 'noreply@anthropic.com' | grep -v '@example\.\(com\|org\)' | sort -u | wc -l)
echo "Unredacted emails in .gz files: $gz_email_count"

# Token pattern check
token_count=$(find "$PUB_DIR" -type f ! -path '*/.git/*' ! -name '*.gz' \
    -exec grep -hoE '(sk-[A-Za-z0-9]{40,}|AKIA[0-9A-Z]{16,}|ghp_[A-Za-z0-9]{36,}|xox[bp]-[A-Za-z0-9-]{40,})' {} \; 2>/dev/null | wc -l)
echo "Token patterns found: $token_count"

# Public IP check
public_ip_count=$(find "$PUB_DIR" -type f ! -path '*/.git/*' ! -name '*.gz' \
    -exec grep -hoE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' {} \; 2>/dev/null | \
    grep -v '^\(127\|0\|10\|192\.168\|172\.\(1[6-9]\|2[0-9]\|3[01]\)\)' | sort -u | wc -l)
echo "Public IP addresses found: $public_ip_count"

echo ""

# === FINAL STATISTICS ===

total_size=$(du -sh "$PUB_DIR" 2>/dev/null | cut -f1)
total_bytes=$(du -s "$PUB_DIR" 2>/dev/null | cut -f1)
file_count=$(find "$PUB_DIR" -type f 2>/dev/null | wc -l)
run_count=$(find "$PUB_DIR/runs" -maxdepth 1 -type d ! -name 'runs' 2>/dev/null | wc -l)

echo "=== EXPORT COMPLETE ==="
echo "Location: $PUB_DIR"
echo "Total size: $total_size"
echo "Total files: $file_count"
echo "Run count: $run_count"
echo ""

if (( total_bytes > 314572800 )); then
    echo "⚠ Size check: ${total_size} (target: <300MB)"
    echo ""
    echo "15 Largest files:"
    find "$PUB_DIR" -type f 2>/dev/null -exec du -b {} \; | sort -rn | head -15 | awk '{
        size=$1; file=$0; sub(/^[0-9]+\s+/, "", file);
        if(size > 1073741824) printf "  %-60s %.1fG\n", file, size/1073741824;
        else if(size > 1048576) printf "  %-60s %.1fM\n", file, size/1048576;
        else printf "  %-60s %.1fK\n", file, size/1024
    }'
else
    echo "✓ Size within budget: ${total_size}"
fi

log "Export script done."
