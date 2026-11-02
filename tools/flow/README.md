# Block Flow: from spec to verified RTL with `make <block>`

`make -f tools/flow/flow.mk <block>` takes a peripheral's spec and runs the `NEX.md` block workflow on its own:

```
spec ──► RTL (rtl-from-spec) ─┐
     └─► testbench (tb-from-spec) ─┴─► independent lint ──► regression + triage ──► fix ──► rerun ──► PASS
           (in parallel)                                     (regress-triage)        (up to MAX_ROUNDS)
```

You write the spec. The flow writes the RTL and the testbench, lints them, runs the regression, fixes RTL, testbench and coverage failures itself, and stops when `make regress` passes. It only comes back to you when something has to be decided in the spec.

> **Status: experimental.** Tested end to end against a simulated `nex`; the first real run (I2C) is in progress. Read every report before committing, and report problems to Enio.

---

## 1. One-time setup

Do this once, on **asicfab**.

1. **Install `nex` and its license.** Follow https://docs.chipnexus.ai/getting-started/installation/ (no sudo: put the binary in `~/.local/bin`). Put the license in `~/.bashrc`; the config file is not always picked up:
   ```bash
   export LICENSE_KEY="<your key>"
   export NEX_LICENSE_KEY="<your key>"
   ```
   Check it:
   ```bash
   nex --check-license
   ```
2. **Check the other tools.** All of these must print a path:
   ```bash
   which git python3 make timeout tmux nex
   ```
3. **Clone the repo** (skip if you already have it):
   ```bash
   git clone git@github.com:Purdue-SoCET/AFTxAI.git
   ```

The flow itself needs no install: it is `tools/flow/` in the repo.

---

## 2. Write the spec

The spec is the only input. Everything the flow builds is derived from it, so most problems are fixed here.

**Where it goes.** One folder per block, with the spec inside it:

| Block | Folder | Spec file |
|---|---|---|
| `i2c` | `peripherals/i2c/` | `I2C.md` |
| `spi` | `peripherals/spi/` | `SPI.md` |

The spec may be named `SPEC.md`, `<NAME>.md` (upper case) or `<name>.md`. Blocks are looked up under `peripherals/`, `bus/` and `digital_lib/`. The folder name is the name you pass to `make`.

**What it must contain.** Use `peripherals/i2c/I2C.md` (once merged) or `bus/APB.md` as a template:

- **Interfaces:** every signal, with direction and width. For bus-attached blocks, connect through `apb_completer` (`bus/apb/rtl/`) and `bus_protocol_if` (`bus/generic/`), and name those files.
- **Parameters:** names, legal values, defaults.
- **Register map** (if any): offset, name, access, reset value, fields.
- **Requirements with IDs** (e.g. `I2C-ENG-004`): one testable statement each.
- **Verification:** a test table mapping test IDs (`T01`, …) to requirement IDs, coverage bins, and the Makefile targets `lint`, `sim CFG=<name>`, `regress`, `cov`, `clean`.

**Shared code.** Name the shared files your block uses, and don't ask for changes to them in the spec. If a shared file really needs to change (e.g. `apb_completer`), do that as its own change on `main` first; the flow will not edit existing shared files.

**Review it.** Run the spec through the `md-revision` skill in an interactive `nex` session until there are no open questions. Every ambiguity left in the spec becomes a question or a wrong guess later.

---

## 3. Start a branch from the latest `main`

The flow refuses to run on a branch that doesn't contain `origin/main`, because shared files (`bus/`, `digital_lib/`) would be missing or old.

1. Commit or stash anything in progress first. Git carries uncommitted files across a branch switch, and refuses to switch if they clash.
   ```bash
   git status -sb
   ```
2. Create the branch:
   ```bash
   git fetch origin && git switch -c feat/<block> origin/main
   ```
3. Add the spec and commit it, so that afterwards `git status` shows only what the flow generated:
   ```bash
   git add peripherals/<block>/<BLOCK>.md && git commit -m "docs(<block>): add <BLOCK> spec"
   ```

Ignored simulation output (`xcelium.d/`, `xrun.log`) stays behind when you switch branches. If `peripherals/<block>/` already exists with old files in it, move them out of the way before starting.

---

## 4. Check that the flow finds your block

From the repo root:
```bash
make -f tools/flow/flow.mk flow-list
```
Your block should be listed with its spec path, e.g. `i2c	peripherals/i2c/I2C.md`. If it isn't, check the folder and file name against step 2.

The list also shows blocks that already have RTL, such as `ahb` (`bus/ahb/SPEC.md`). Running the flow on one of those rewrites its RTL and testbench from the spec, so only do it on purpose, on its own branch.

---

## 5. Run it

Runs take hours. Start them inside `tmux` so a dropped connection doesn't kill them:
```bash
tmux new -s <block>-flow
```
Inside tmux, from the repo root:
```bash
make -f tools/flow/flow.mk <block>
```
Detach with `Ctrl-b` then `d`. Reattach later with:
```bash
tmux attach -t <block>-flow
```

**Watching progress.** Everything goes to `peripherals/<block>/build/flow/`:

| File | Contents |
|---|---|
| `<stage>.response.md` | What `nex` replied for that stage |
| `<stage>.report.md` | The skill's report (traceability, lint results, test plan, …) |
| `triage.json`, `triage.r<N>.json` | Regression results and classified failures, per round |
| `*.questions` | Questions the flow needs you to answer in the spec |
| `confirm.log` | The final `make regress` that confirms a pass |

```bash
ls -lt peripherals/<block>/build/flow | head
```

---

## 6. When it stops

| `make` ends with | Meaning | What to do |
|---|---|---|
| `flow: PASS: make regress exited 0` | Regression passes and was confirmed by a real `make regress` | Review and commit (step 7) |
| `Error 2` | A stage had questions about the spec | Read `build/flow/*.questions`, fix the spec, delete the `.questions` files, run `make` again |
| `Error 3` | Regression found a **spec gap** (the spec is ambiguous or silent) | `make -f tools/flow/flow.mk <block>-status`, fix the spec, run `make` again |
| `Error 4` | Fix rounds used up without a clean regression | `<block>-status` to see what's left; rerun with `MAX_ROUNDS=5`, or fix the spec if the same failure keeps coming back |
| `Error 5` | A stage edited an existing file **outside** your block | `git diff <file>`. Undo it (`git checkout -- <file>`) and rerun, or move the change to its own branch for `main` |
| `Error 1` | Anything else (tool missing, `nex` failed, stage stopped early, something NOT RUN) | The message names the stage; read its `.response.md` and `.err` |

Running `make` again starts over from the spec: the previous logs move to `build/flow.prev/`, and the generated RTL and testbench are kept as a starting point. To start completely fresh, delete everything in `peripherals/<block>/` except the spec.

---

## 7. Review and commit

The flow never commits. Before you do:

1. **Read the reports** in `build/flow/`: the RTL traceability table (every requirement ID → where it's implemented), the test plan, lint waivers, coverage and exclusions.
2. **Check the git summary** printed at the end, especially the section **new files outside `<block>/`**. New shared files (e.g. a `digital_lib/` module) affect other blocks and need a reviewer.
3. **Don't commit `build/`.** It isn't in `.gitignore`.
4. **Commit RTL and verification separately**, citing requirement and test IDs, as `NEX.md` asks:
   ```bash
   git add peripherals/<block> ':!peripherals/<block>/verification' ':!peripherals/<block>/build'
   ```
   ```bash
   git commit -m "feat(<block>): RTL from spec"
   ```
   ```bash
   git add peripherals/<block>/verification ':!peripherals/<block>/build'
   ```
   ```bash
   git commit -m "test(<block>): verification from spec"
   ```
5. Push the branch and open a PR. A teammate reviews it like any other code.

---

## Options

Pass them after the target, e.g. `make -f tools/flow/flow.mk i2c MAX_ROUNDS=5`.

| Option | Default | Meaning |
|---|---|---|
| `MAX_ROUNDS` | `3` | Fix → regression rounds before giving up |
| `STAGE_TIMEOUT` | `4h` | Time limit for each `nex` call |
| `AUTO_APPROVE` | `1` | `0` stops before each fix so you approve it yourself (the original `NEX.md` rule) |

**Manual approval mode** (`AUTO_APPROVE=0`): after a stop with `Error 3`, review the failures, then approve and fix with `flow.sh` directly:
```bash
bash tools/flow/flow.sh status <block>
```
```bash
bash tools/flow/flow.sh approve <block> F01 F03
```
```bash
bash tools/flow/flow.sh fix <block>
```
`approve <block> all` approves every RTL/testbench/coverage failure. Spec gaps can't be approved; they go back to the spec.

Other settings are environment variables, documented at the top of `flow.sh`: `BLOCK_PARENTS`, `ALLOW_STALE`, `SKILLS_DIR`, `NEX`.

---

## What the flow guarantees

- **RTL and testbench are written in parallel and independently**, both from the spec, in separate `nex` sessions (`<block>-rtl`, `<block>-verif`). The testbench session is told not to read the RTL. This is an instruction, not enforced; the flow only warns if its output names RTL files.
- **Shared code is protected.** Editing an existing file outside the block stops the flow (exit 5). New files outside the block are allowed and listed for review.
- **A pass is real.** The flow doesn't trust the triage report: it runs `make regress` itself and goes by its exit code. Anything NOT RUN (missing tool or license) is never reported as a pass.
- **Nothing is committed or pushed**, and no branches are switched mid-run. On `main`, it creates `feat/<block>` before starting.
- **One run per block at a time** (lock: `peripherals/<block>/build/flow.lock`).

## Troubleshooting

| Problem | Fix |
|---|---|
| `this branch doesn't contain origin/main` | Rebase onto `origin/main`, or start a new branch from it (step 3) |
| `another flow is running for <block>` | If none is running (e.g. after a crash), remove `peripherals/<block>/build/flow.lock` |
| `no block named '<block>'` | Folder or spec name doesn't match step 2; check `flow-list` |
| `<stage> stopped without writing its report` | `nex` stopped to ask something. Its last reply is printed; answer it in the spec and rerun |
| `the approval policy blocked a tool call` | `nex` auto mode only allows paths inside the repo. Keep everything the spec references inside the repo |
| `nex exit …, status …` | Check `nex --check-license`; read the stage's `.err` |
| New `nex` version | The flow reads `nex --json-output` (tested with v5.74.0). After upgrading, check `nex -p "reply ok" --json-output` still has `status`, `session_id` and `response` |

## Files

| File | Purpose |
|---|---|
| `flow.mk` | `make <block>`, `make <block>-status`, `make flow-list` |
| `flow.sh` | The flow itself; usage at the top of the file |
| `TRIAGE_FORMAT.md` | Format of `triage.json`, the regression stage's machine-readable output |
| `triage.example.json` | A filled-in example |

The stage instructions are the skills in `skills/` (`rtl-from-spec`, `tb-from-spec`, `regress-triage`); improve those to improve what the flow produces.
