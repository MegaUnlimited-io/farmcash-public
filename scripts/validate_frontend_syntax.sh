#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HTML_FILE="$ROOT_DIR/index.html"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required for syntax validation" >&2
  exit 1
fi

python - "$HTML_FILE" <<'PY'
import re
import sys
from pathlib import Path

html_path = Path(sys.argv[1])
html = html_path.read_text()
scripts = re.findall(r'<script>(.*?)</script>', html, flags=re.S)
if not scripts:
    raise SystemExit('No inline <script> blocks found in index.html')

tmp_dir = Path('/tmp/farmcash-script-parse')
tmp_dir.mkdir(parents=True, exist_ok=True)
for i, script in enumerate(scripts, start=1):
    (tmp_dir / f'script_{i}.js').write_text(script)
print(f'Wrote {len(scripts)} script blocks to {tmp_dir}')
PY

node <<'NODE'
const fs = require('fs');
const vm = require('vm');
const dir = '/tmp/farmcash-script-parse';
const files = fs.readdirSync(dir).filter(f => f.endsWith('.js')).sort();
let hasError = false;
for (const file of files) {
  const source = fs.readFileSync(`${dir}/${file}`, 'utf8');
  try {
    new vm.Script(source);
    console.log(`OK ${file}`);
  } catch (err) {
    hasError = true;
    console.error(`ERR ${file}: ${err.message}`);
  }
}
if (hasError) process.exit(1);
NODE

echo "Frontend inline script syntax validation passed."
