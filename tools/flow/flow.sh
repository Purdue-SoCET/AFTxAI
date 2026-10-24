#!/usr/bin/env bash
# flow.sh: run the NEX.md "Block Workflow" headlessly with nex, stopping at each human gate.
#
# Usage (from inside the AFTxAI checkout, on asicfab). <block> is a block name (i2c)
# or its spec path (peripherals/i2c/I2C.md):
#   flow.sh run     <block>                stages 2a || 2b, 3 and 4; stops at the first gate
#   flow.sh status  <block>                print the current triage table
#   flow.sh approve <block> <F01 ...|all>  approve failures (all = every rtl/tb/coverage failure)
#   flow.sh fix     <block>                send approved failures to the RTL/TB sessions, rerun 3 and 4
#   flow.sh list                           blocks that have a spec
# `make <block>` (flow.mk) runs `run` with AUTO_APPROVE=1.
#
# A block is a folder under BLOCK_PARENTS that holds its spec: SPEC.md, <NAME>.md or <name>.md
# (e.g. peripherals/i2c/I2C.md). Stage 1 (spec review) stays manual: freeze the spec first.
# State, logs and reports go to <block>/build/flow/ (`make clean` deletes them).
#
# Exit codes:
#   0  triage reports no failures and `make regress` confirms it
#   1  error, or something was NOT RUN
#   2  questions to answer in the spec (<block>/build/flow/*.questions)
#   3  failures waiting for approval, or spec gaps
#   4  MAX_ROUNDS fix rounds done without a clean regression
#   5  a stage changed existing files outside the block (shared code needs a person)
#
# Environment:
#   BLOCK_PARENTS  folders holding blocks (default: "peripherals bus digital_lib")
#   ALLOW_STALE    1 = run on a branch that doesn't contain origin/main (default: 0)
#   SKILLS_DIR     skills folder (default: <repo>/skills). Must be inside the repo: with
#                  --approval-policy auto, nex blocks paths outside the project folder.
#   MAX_ROUNDS     fix rounds allowed (default: 3)
#   AUTO_APPROVE   1 = approve every rtl/tb/coverage failure without asking and keep looping.
#                  This skips the NEX.md rule that the user decides each fix. Spec gaps still stop.
#   STAGE_TIMEOUT  limit for each nex call, in timeout(1) syntax (default: 4h)
#   NEX            nex binary (default: nex)

set -uo pipefail
shopt -s nullglob

WORKFLOW_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FORMAT_DOC=$WORKFLOW_DIR/TRIAGE_FORMAT.md
NEX=${NEX:-nex}
MAX_ROUNDS=${MAX_ROUNDS:-3}
AUTO_APPROVE=${AUTO_APPROVE:-0}
STAGE_TIMEOUT=${STAGE_TIMEOUT:-4h}
BLOCK_PARENTS=${BLOCK_PARENTS:-"peripherals bus digital_lib"}
ALLOW_STALE=${ALLOW_STALE:-0}

die()  { echo "flow: $*" >&2; exit 1; }
info() { echo "flow: $*"; }
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 1; }

# ---------------------------------------------------------------------------
# triage.json and nex output helpers (python3, standard library only)
# ---------------------------------------------------------------------------
tri() {
  python3 - "$@" <<'PY' | tr -d '\r'
import json, re, sys

cmd, args = sys.argv[1], sys.argv[2:]
OWNER = {"rtl": "rtl", "tb": "tb", "coverage": "tb"}

def load(path):
    with open(path) as fh:
        return json.load(fh)

def save(path, data):
    with open(path, "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")

if cmd == "result":
    # nex --json-output: {"status": 200, "session_id": ..., "response": ..., "stats": {...}}.
    # nex can print an update banner before the JSON, and exits 0 even when the
    # approval policy blocks a tool call, so parse from the first line starting
    # with "{" and report blocked calls. The response text goes to args[1].
    d = {}
    try:
        with open(args[0]) as fh:
            text = fh.read()
        m = re.search(r"^\{", text, re.M)
        if m:
            d, _ = json.JSONDecoder().raw_decode(text[m.start():])
    except (OSError, ValueError):
        pass
    if not isinstance(d, dict):
        d = {}
    response = str(d.get("response", ""))
    with open(args[1], "w") as fh:
        fh.write(response + "\n")
    blocked = "blocked by the active approval policy" in response
    print(d.get("status", 0), d.get("session_id") or "-", int(blocked))

elif cmd == "validate":
    path, want_round = args[0], int(args[1])
    try:
        d = load(path)
    except FileNotFoundError:
        sys.exit("missing")
    except ValueError as e:
        sys.exit(f"not valid JSON: {e}")
    errs = [f"missing field '{k}'" for k in
            ("spec", "round", "generated", "tools", "summary", "results", "failures", "coverage", "not_run")
            if k not in d]
    if errs:
        sys.exit("\n".join(errs))
    if d["round"] != want_round:
        errs.append(f"round is {d['round']}, expected {want_round}")
    counts = {"PASS": 0, "FAIL": 0, "NOT_RUN": 0}
    for r in d["results"]:
        if r.get("status") in counts:
            counts[r["status"]] += 1
        else:
            errs.append(f"result {r.get('test')}: bad status {r.get('status')!r}")
    want = {"pass": counts["PASS"], "fail": counts["FAIL"], "not_run": counts["NOT_RUN"]}
    got = {k: d["summary"].get(k) for k in want}
    if got != want:
        errs.append(f"summary {got} does not match results {want}")
    seen = set()
    for f in d["failures"]:
        fid = f.get("id", "?")
        errs += [f"{fid}: missing '{k}'" for k in
                 ("id", "test", "config", "seed", "class", "requirements", "summary", "evidence", "proposed_fix", "approved")
                 if k not in f]
        if fid in seen:
            errs.append(f"duplicate id {fid}")
        seen.add(fid)
        if f.get("class") not in ("rtl", "tb", "spec", "coverage"):
            errs.append(f"{fid}: bad class {f.get('class')!r}")
        if not f.get("requirements"):
            errs.append(f"{fid}: no requirement IDs")
        if f.get("approved") is not False:
            errs.append(f"{fid}: approved must start as false")
    if not d["failures"]:
        if want["fail"]:
            errs.append("tests failed but failures[] is empty")
        if any(not c.get("met") for c in d["coverage"]):
            errs.append("a coverage target is unmet but failures[] is empty")
    if errs:
        sys.exit("\n".join(errs))

elif cmd == "counts":
    d = load(args[0])
    nspec = sum(f["class"] == "spec" for f in d["failures"])
    nnotrun = d["summary"].get("not_run", 0) + len(d["not_run"])
    print(len(d["failures"]), nspec, nnotrun)

elif cmd == "status":
    d = load(args[0])
    s = d["summary"]
    print(f"round {d['round']}: {s.get('pass', 0)} pass, {s.get('fail', 0)} fail, {s.get('not_run', 0)} not run")
    for c in d["coverage"]:
        if not c.get("met"):
            print(f"  coverage {c['metric']} [{c['config']}]: {c['result']} < {c['target']}")
    for n in d["not_run"]:
        print(f"  NOT RUN {n.get('what')}: {str(n.get('error', ''))[:100]}")
    if d["failures"]:
        print(f"  {'ID':<4} {'CLASS':<9} {'TEST':<5} {'CONFIG':<12} {'OK':<4} REQUIREMENTS")
        for f in d["failures"]:
            ok = "yes" if f.get("approved") else "no"
            print(f"  {f['id']:<4} {f['class']:<9} {f['test']:<5} {f['config']:<12} {ok:<4} {', '.join(f['requirements'])}")
            print(f"       {f['summary']}")

elif cmd == "approve":
    path, ids = args[0], args[1:]
    d = load(path)
    by_id = {f["id"]: f for f in d["failures"]}
    if ids == ["all"]:
        ids = [i for i, f in by_id.items() if f["class"] != "spec"]
    for i in ids:
        if i not in by_id:
            sys.exit(f"unknown failure id {i}")
        if by_id[i]["class"] == "spec":
            sys.exit(f"{i} is a spec gap; resolve it in the spec instead")
    for i in ids:
        by_id[i]["approved"] = True
    save(path, d)
    print("approved: " + (", ".join(ids) or "nothing"))

elif cmd == "extract":
    # Split approved failures by owner into <prefix>.rtl.json / <prefix>.tb.json.
    d, prefix = load(args[0]), args[1]
    n = {"rtl": 0, "tb": 0}
    for owner in n:
        sel = [f for f in d["failures"] if f.get("approved") and OWNER.get(f["class"]) == owner]
        n[owner] = len(sel)
        if sel:
            save(f"{prefix}.{owner}.json", {"spec": d["spec"], "round": d["round"], "failures": sel})
    print(n["rtl"], n["tb"])

else:
    sys.exit(f"tri: unknown command {cmd}")
PY
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
[[ $# -ge 1 ]] || usage
CMD=$1; shift

command -v git >/dev/null || die "git not found"
command -v python3 >/dev/null || die "python3 not found"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "run this inside the AFTxAI checkout"
ROOT=$(cd "$ROOT" && pwd -P)

# spec_in <dir>: the spec file in a block folder, if it has one.
spec_in() {
  local d=$1 n f
  n=$(basename "$d")
  for f in "$d/SPEC.md" "$d/${n^^}.md" "$d/$n.md"; do
    [[ -f $f ]] && { echo "$f"; return 0; }
  done
  return 1
}

# list_blocks: "<name><TAB><spec path>" for every block folder with a spec.
list_blocks() {
  local p d s
  for p in $BLOCK_PARENTS; do
    for d in "$ROOT/$p"/*/; do
      s=$(spec_in "${d%/}") && printf '%s\t%s\n' "$(basename "$d")" "${s#"$ROOT"/}"
    done
  done
}

if [[ $CMD == list ]]; then
  list_blocks
  exit 0
fi

[[ $# -ge 1 ]] || usage
TARGET=$1; shift
if [[ -f $TARGET ]]; then
  SPEC_ARG=$TARGET
else
  matches=$(list_blocks | awk -F'\t' -v n="$TARGET" '$1 == n { print $2 }')
  [[ -n $matches ]] || die "no block named '$TARGET' with a spec under: $BLOCK_PARENTS (see: flow.sh list)"
  (( $(wc -l <<<"$matches") == 1 )) || die "'$TARGET' is ambiguous; pass the spec path instead:
$matches"
  SPEC_ARG=$ROOT/$matches
fi
SPEC_ABS=$(cd "$(dirname "$SPEC_ARG")" && pwd -P)/$(basename "$SPEC_ARG")
SPEC=${SPEC_ABS#"$ROOT"/}
[[ $SPEC != "$SPEC_ABS" ]] || die "spec must be inside $ROOT"
BLK=$(dirname "$SPEC")
BLOCK=$(basename "$BLK")
LOG=$ROOT/$BLK/build/flow
LOCK=$ROOT/$BLK/build/flow.lock
TRIAGE=$LOG/triage.json
SKILLS_DIR=${SKILLS_DIR:-$ROOT/skills}

preflight() {
  command -v "$NEX" >/dev/null || die "nex not found (set NEX=...)"
  command -v timeout >/dev/null || die "timeout not found"
  local s br
  for s in rtl-from-spec tb-from-spec regress-triage; do
    [[ -f $SKILLS_DIR/$s/SKILL.md ]] || die "missing $SKILLS_DIR/$s/SKILL.md (set SKILLS_DIR=...)"
  done
  [[ -f $FORMAT_DOC ]] || die "missing $FORMAT_DOC"

  # Shared code (bus/, digital_lib/) comes from main. On a branch without it, the
  # sessions recreate shared files instead of using them.
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" \
    timeout 60 git -C "$ROOT" fetch -q origin main 2>/dev/null \
    || info "warning: could not fetch origin/main; checking against the local copy"
  if git -C "$ROOT" rev-parse -q --verify origin/main >/dev/null \
     && ! git -C "$ROOT" merge-base --is-ancestor origin/main HEAD && [[ $ALLOW_STALE != 1 ]]; then
    die "this branch doesn't contain origin/main, so shared files (bus/, digital_lib/) may be missing or old.
Rebase onto origin/main first, or set ALLOW_STALE=1."
  fi

  # NEX.md: work on a feature branch, and never switch during a task. Both parallel
  # sessions share this checkout, so the branch is settled here, before either starts.
  br=$(git -C "$ROOT" branch --show-current)
  [[ -n $br ]] || die "detached HEAD; check out a branch first"
  if [[ $br == main || $br == master ]]; then
    git -C "$ROOT" switch -c "feat/$BLOCK" || die "could not create branch feat/$BLOCK"
    info "created branch feat/$BLOCK"
  fi

  mkdir -p "$ROOT/$BLK/build"
  mkdir "$LOCK" 2>/dev/null || die "another flow is running for $BLOCK (if not, remove ${LOCK#"$ROOT"/})"
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  trap 'kill $(jobs -p) 2>/dev/null; exit 130' INT TERM
}

# Rules added to every prompt: nobody can answer questions in a -p run.
headless_rules() {  # headless_rules <log-name>
  cat <<EOF

You are running headless inside flow.sh; nobody can answer questions during this run.
These rules override the skill where they conflict:
- Wherever you would stop and ask the user, instead write each question, with the requirement IDs involved, to $LOG/$1.questions, then stop.
- Do not create, switch or commit branches, and do not commit. The branch is already set; the user commits after review.
- Do not modify or delete existing files outside $BLK/ (shared bus interfaces, digital_lib/, other blocks). Use them as they are. If the spec seems to need such a change, write it as a question instead. You may create new files outside $BLK/ that the spec asks for, kept minimal.
- Write your final report to $LOG/$1.report.md.
EOF
}

# outside_changes: `git status` lines for paths outside the block folder.
outside_changes() {
  git -C "$ROOT" status --porcelain=v1 --untracked-files=all \
    | awk -v blk="$BLK/" '{ p = substr($0, 4); sub(/.* -> /, "", p) } index(p, blk) != 1'
}

# Existing files outside the block are shared with other blocks. A stage may add new
# files there, but a change to an existing one needs a person, so the flow stops.
# Compared against the snapshot taken when `run` started, so your own edits don't count.
check_scope() {
  local changed
  changed=$(comm -13 "$LOG/outside.base" <(outside_changes | sort) | grep -v '^?? \|^A  ')
  [[ -n $changed ]] || return 0
  echo "$changed"
  info "a stage changed existing files outside $BLK/ (above). Shared code affects other blocks,"
  info "so review it: keep it as its own change, or revert it (git checkout -- <file>) and rerun."
  git_summary
  exit 5
}

# nex_run <log-name> <role> <prompt>: one headless nex call from the repo root.
# Roles match the NEX.md session names: rtl = <block>-rtl, verif = <block>-verif.
# Resumes the role's earlier session if nex reported a session id for it.
nex_run() {
  local name=$1 role=$2 prompt=$3 sid="" rc status blocked
  [[ -s $LOG/sessions/$role ]] && sid=$(<"$LOG/sessions/$role")
  local args=(-p "$prompt" --approval-policy auto --json-output)
  [[ -n $sid ]] && args+=(-s "$sid")
  (cd "$ROOT" && timeout "$STAGE_TIMEOUT" "$NEX" "${args[@]}") >"$LOG/$name.json" 2>"$LOG/$name.err"
  rc=$?
  read -r status sid blocked < <(tri result "$LOG/$name.json" "$LOG/$name.response.md")
  [[ $sid != - ]] && echo "$sid" >"$LOG/sessions/$role"
  (( blocked )) && info "warning: the approval policy blocked a tool call in $name (see ${LOG#"$ROOT"/}/$name.response.md)"
  (( rc == 0 && status == 200 )) || { info "$name: nex exit $rc, status $status (see ${LOG#"$ROOT"/}/$name.err)"; return 1; }
  # With -p, nex can stop to ask a question and still return status 200. A stage
  # that finished wrote its report; one that wrote questions is handled by questions_gate.
  [[ -s $LOG/$name.questions ]] && return 1
  if [[ ! -s $LOG/$name.report.md ]]; then
    info "$name stopped without writing its report; its last response:"
    sed 's/^/    /' "$LOG/$name.response.md"
    return 1
  fi
}

# The block's RTL and interface files: every .sv outside verification/ and build/.
# Works for both the include/ + rtl/ layout and a flat block folder.
rtl_files() {
  find "$ROOT/$BLK" \( -path "$ROOT/$BLK/verification" -o -path "$ROOT/$BLK/build" \) -prune \
    -o -name '*.sv' -print | sort
}

makefile_dir() {
  local d
  for d in "$ROOT/$BLK" "$ROOT/$BLK/verification"; do
    [[ -f $d/Makefile ]] && { echo "$d"; return; }
  done
}

questions_gate() {
  local f found=0
  for f in "$LOG"/*.questions; do
    [[ -s $f ]] || continue
    found=1
    echo "=== ${f##*/}"
    cat "$f"
  done
  if (( found )); then
    info "answer these in the spec (stage 1, md-revision), delete the .questions files, then rerun"
    exit 2
  fi
}

git_summary() {
  local added
  echo "--- git status"
  git -C "$ROOT" status --short
  echo "--- git diff --stat"
  git -C "$ROOT" diff --stat
  added=$(comm -13 "$LOG/outside.base" <(outside_changes | sort) | grep '^?? \|^A  ')
  if [[ -n $added ]]; then
    echo "--- new files outside $BLK/ (shared; review before committing)"
    echo "$added"
  fi
}

# ---------------------------------------------------------------------------
# Stages
# ---------------------------------------------------------------------------
stage2() {
  info "stage 2: RTL ($BLOCK-rtl) and testbench ($BLOCK-verif) in parallel"
  local p_rtl p_tb rc_rtl rc_tb
  nex_run rtl rtl "Follow $SKILLS_DIR/rtl-from-spec/SKILL.md with \$ARGUMENTS = $SPEC.
$(headless_rules rtl)" &
  p_rtl=$!
  nex_run tb verif "Follow $SKILLS_DIR/tb-from-spec/SKILL.md with \$ARGUMENTS = $SPEC.
Do not open or search this block's RTL files (any .sv in $BLK/ outside verification/, except *_if.sv interface files); the RTL is being written at the same time.
$(headless_rules tb)" &
  p_tb=$!
  wait "$p_rtl"; rc_rtl=$?
  wait "$p_tb"; rc_tb=$?
  check_scope

  # Heuristic only: nex has no flag to block paths, so check its output for RTL paths.
  if grep -qF -f <(rtl_files | grep -v '_if\.sv$' | sed "s|^$ROOT/||") "$LOG/tb.json" 2>/dev/null; then
    info "warning: the TB stage output names RTL files; check that it only compiled against them"
  fi
  questions_gate
  (( rc_rtl == 0 && rc_tb == 0 )) || die "stage 2 failed"
  [[ -n $(rtl_files) ]] || die "no RTL (.sv outside verification/) in $BLK/"
  [[ -n $(makefile_dir) ]] || die "no Makefile in $BLK/ or $BLK/verification/"
}

stage3() {
  info "stage 3: independent lint"
  rm -f "$LOG"/lint_*
  local f rel pids=()
  # One linter call per file, all at once: each call takes minutes.
  while read -r f; do
    rel=${f#"$ROOT"/}
    (cd "$ROOT" && timeout "$STAGE_TIMEOUT" "$NEX" --agent=linter --input-file="$rel" --json-output \
      >"$LOG/lint_$(basename "$f" .sv).json" 2>"$LOG/lint_$(basename "$f" .sv).err" \
      || info "linter exited non-zero on $rel") &
    pids+=($!)
  done < <(rtl_files)
  (( ${#pids[@]} )) && wait "${pids[@]}"
}

stage4() {  # stage4 <round>
  local round=$1 err
  info "stage 4: regression and triage, round $round"
  rm -f "$TRIAGE"
  # nex can't read outside the repo in auto mode, so give it a copy of the format.
  cp "$FORMAT_DOC" "$LOG/TRIAGE_FORMAT.md"
  nex_run "regress.r$round" verif "Follow $SKILLS_DIR/regress-triage/SKILL.md with \$ARGUMENTS = $SPEC.
This is round $round. Independent linter results are in $LOG/lint_*.json; list each real issue there as a failure with test \"LINT\" and class \"rtl\".
In addition to your report, write $TRIAGE exactly in the format described in $LOG/TRIAGE_FORMAT.md, with round = $round and every failure approved = false.
Do not apply testbench fixes or add tests in this run, even ones you would normally propose; flow.sh applies them after the user approves them.
$(headless_rules "regress.r$round")"
  check_scope
  questions_gate
  err=$(tri validate "$TRIAGE" "$round" 2>&1) \
    || die "triage.json rejected:
$err
(report: ${LOG#"$ROOT"/}/regress.r$round.report.md)"
  cp "$TRIAGE" "$LOG/triage.r$round.json"
  echo "$round" >"$LOG/round"
}

# After a validated triage: exits at every gate; returns only to keep looping with AUTO_APPROVE.
decide() {
  local nfail nspec nnotrun mk
  read -r nfail nspec nnotrun < <(tri counts "$TRIAGE")

  if (( nfail == 0 )); then
    tri status "$TRIAGE"
    if (( nnotrun > 0 )); then
      info "$nnotrun item(s) NOT RUN; not claiming a pass"
      git_summary
      exit 1
    fi
    # The triage is a report, not proof: confirm with the real exit code.
    mk=$(makefile_dir)
    info "triage reports no failures; confirming with make regress"
    if make -C "$mk" regress >"$LOG/confirm.log" 2>&1; then
      info "PASS: make regress exited 0 (log: ${LOG#"$ROOT"/}/confirm.log)"
      git_summary
      exit 0
    fi
    die "triage.json reports a pass, but make regress failed; see ${LOG#"$ROOT"/}/confirm.log"
  fi

  tri status "$TRIAGE"
  if (( nspec > 0 )); then
    info "$nspec spec gap(s): resolve them in the spec (stage 1). Other failures can still be approved and fixed."
    git_summary
    exit 3
  fi
  [[ $AUTO_APPROVE == 1 ]] && return 0
  info "next: review the failures and reports in ${LOG#"$ROOT"/}/, then"
  info "  flow.sh approve $SPEC <F01 ...|all> && flow.sh fix $SPEC"
  git_summary
  exit 3
}

fix_prompt() {  # fix_prompt rtl|tb <round>
  local who=$1 round=$2 file=$LOG/fix.r$2.$1.json
  if [[ $who == rtl ]]; then
    cat <<EOF
Regression on $SPEC found the RTL bugs listed in $file. The user approved the proposed fix for each one.
Fix only these, in the block's RTL and interface files under $BLK/, following NEX.md and the spec. Do not create or edit anything under $BLK/verification/.
If a proposed fix contradicts the spec, do not apply it; write a question instead.
Then lint until clean, as in step 5 of $SKILLS_DIR/rtl-from-spec/SKILL.md.
EOF
  else
    cat <<EOF
Regression on $SPEC found the testbench bugs and coverage gaps listed in $file. The user approved the proposed fix for each one.
Fix only these, in $BLK/verification/. Do not edit anything in $BLK/ outside verification/.
Never change an expected value, remove a check or lower a coverage target unless the approved fix says so and cites the spec.
Compile and run only the affected tests once; flow.sh reruns the full regression afterwards.
EOF
  fi
  headless_rules "fix.r$round.$who"
}

do_fix() {
  [[ -f $TRIAGE && -f $LOG/round ]] || die "no triage.json yet; run: flow.sh run $SPEC"
  local round nrtl ntb p_rtl p_tb rc
  round=$(<"$LOG/round")
  while :; do
    if (( round > MAX_ROUNDS )); then
      info "stopping: $MAX_ROUNDS fix round(s) done without a clean regression (MAX_ROUNDS)"
      tri status "$TRIAGE"
      git_summary
      exit 4
    fi
    [[ $AUTO_APPROVE == 1 ]] && tri approve "$TRIAGE" all
    read -r nrtl ntb < <(tri extract "$TRIAGE" "$LOG/fix.r$round")
    (( nrtl + ntb > 0 )) || die "nothing approved; run: flow.sh approve $SPEC <F01 ...|all>"

    info "fix round $round: $nrtl RTL, $ntb testbench"
    p_rtl="" p_tb="" rc=0
    if (( nrtl > 0 )); then nex_run "fix.r$round.rtl" rtl "$(fix_prompt rtl "$round")" & p_rtl=$!; fi
    if (( ntb > 0 )); then nex_run "fix.r$round.tb" verif "$(fix_prompt tb "$round")" & p_tb=$!; fi
    [[ -n $p_rtl ]] && { wait "$p_rtl" || rc=1; }
    [[ -n $p_tb ]] && { wait "$p_tb" || rc=1; }
    check_scope
    questions_gate
    (( rc == 0 )) || die "fix round $round failed"

    round=$((round + 1))
    stage3
    stage4 "$round"
    decide
  done
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
case $CMD in
  run)
    preflight
    if [[ -d $LOG ]]; then
      rm -rf "$LOG.prev"
      mv "$LOG" "$LOG.prev"
      info "previous flow state moved to ${LOG#"$ROOT"/}.prev"
    fi
    mkdir -p "$LOG/sessions"
    outside_changes | sort >"$LOG/outside.base"
    stage2
    stage3
    stage4 1
    decide
    do_fix
    ;;
  fix)
    preflight
    [[ -f $LOG/outside.base ]] || outside_changes | sort >"$LOG/outside.base"
    do_fix
    ;;
  status)
    [[ -f $TRIAGE ]] || die "no triage.json yet; run: flow.sh run $SPEC"
    tri status "$TRIAGE"
    ;;
  approve)
    [[ -f $TRIAGE ]] || die "no triage.json yet; run: flow.sh run $SPEC"
    (( $# > 0 )) || die "name failure IDs (F01 F02 ...) or all"
    tri approve "$TRIAGE" "$@"
    ;;
  *)
    usage
    ;;
esac
