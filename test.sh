#!/usr/bin/env bash
# Smoke test: exercise the full pharmit pipeline end to end.
#   pharma   — identify pharmacophore features
#   dbcreate — build a searchable database (links smina minimization)
#   dbsearch — query the database and return hits
# Fetches a 3D SDF from PubChem at runtime (CID 2244, aspirin).
# NOTE: requires outbound HTTPS and python3 — run on a node with internet (login node).
set -uo pipefail

ROOT="${PIXI_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PHARMIT="$ROOT/build/pharmit"
CID=2244   # aspirin
SDF_URL="https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/${CID}/record/SDF?record_type=3d"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "TEST FAIL: $1" >&2; exit 1; }

# 0. binary exists
[[ -x "$PHARMIT" ]] || fail "binary not found at $PHARMIT (run 'pixi run build')"

# 1. binary runs and prints its command list
#    (pharmit exits 255 when run with no command — expected, hence `|| true`)
out="$("$PHARMIT" 2>&1 || true)"
printf '%s' "$out" | grep -q "dbcreate" || fail "binary did not print expected command list"
echo "  [1/5] binary runs and lists commands"

# 2. fetch a 3D test molecule from PubChem
curl -fsSL "$SDF_URL" -o "$TMP/mol.sdf" \
  || fail "could not fetch SDF from PubChem (no network? run on a login node)"
grep -q "V2000\|V3000" "$TMP/mol.sdf" || fail "fetched file is not a valid SDF"
echo "  [2/5] fetched 3D molecule (PubChem CID $CID)"

# 3. pharma: identify pharmacophore features
"$PHARMIT" pharma -in="$TMP/mol.sdf" -out="$TMP/pharma.json" 2>/dev/null
grep -q '"name"' "$TMP/pharma.json" || fail "pharma produced no pharmacophore points"
echo "  [3/5] pharma identified pharmacophore features"

# 4. dbcreate: build a searchable database
"$PHARMIT" dbcreate -in="$TMP/mol.sdf" -dbdir="$TMP/db" >/dev/null 2>&1 \
  || fail "dbcreate failed"
[[ -f "$TMP/db/dbinfo.json" ]] || fail "dbcreate did not produce a database"
echo "  [4/5] dbcreate built a pharmacophore database"

# 5. dbsearch: build a minimal 3-point query from the molecule's own features,
#    then search the db — the molecule must match itself.
python3 - "$TMP/pharma.json" "$TMP/query.json" << 'PYEOF'
import json, sys
text = open(sys.argv[1]).read()
obj, _ = json.JSONDecoder().raw_decode(text.lstrip())   # pharma emits concatenated objects; take first
chosen, seen = [], set()
for p in obj["points"]:
    if p["name"] not in seen:
        chosen.append({"name": p["name"], "x": p["x"], "y": p["y"], "z": p["z"],
                       "radius": 1.5, "enabled": True})
        seen.add(p["name"])
    if len(chosen) == 3:
        break
json.dump({"points": chosen}, open(sys.argv[2], "w"))
PYEOF
[[ -s "$TMP/query.json" ]] || fail "could not build query"

"$PHARMIT" dbsearch -dbdir="$TMP/db" -in="$TMP/query.json" -out="$TMP/hits.sdf" >"$TMP/search.log" 2>&1 \
  || fail "dbsearch crashed (exit $?) — see Eigen alignment / minimization path"
n="$(grep -oE 'NumResults: [0-9]+' "$TMP/search.log" | grep -oE '[0-9]+' || echo 0)"
[[ -s "$TMP/hits.sdf" ]] || fail "dbsearch returned no hits (NumResults=$n)"
echo "  [5/5] dbsearch found $n hit(s) and wrote results"

echo "TEST PASS: full pipeline functional (pharma + dbcreate + dbsearch)"
