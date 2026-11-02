# `triage.json` format

`triage.json` is the machine-readable output of the `regress-triage` stage. `flow.sh` reads it to decide what happens next. The skill still writes its normal Markdown report; this file is written alongside it.

**Location:** `<block>/build/flow/triage.json` (for example `peripherals/i2c/build/flow/triage.json`). `flow.sh` keeps a copy of each round as `triage.r<N>.json`.

**Note:** `make clean` removes `build/`, and with it the flow state. Run it only between flows.

---

## Top level

| Field | Type | Required | Meaning |
|---|---|---|---|
| `spec` | string | yes | Spec path, relative to the repo root (e.g. `peripherals/i2c/I2C.md`) |
| `round` | integer | yes | Regression round, starting at 1. `flow.sh` passes this in the prompt |
| `generated` | string | yes | ISO-8601 UTC timestamp |
| `tools` | object | yes | Tool name → version actually used (e.g. `"verilator": "5.036"`) |
| `summary` | object | yes | `{"pass": int, "fail": int, "not_run": int}`, counted over `results` |
| `results` | array | yes | One entry per test × configuration (below) |
| `failures` | array | yes | One entry per distinct failure (below). Empty if everything passed |
| `coverage` | array | yes | One entry per metric × configuration (below) |
| `not_run` | array | yes | Anything that could not run: `{"what": string, "error": string}` |

## `results[]`

| Field | Type | Meaning |
|---|---|---|
| `test` | string | Test ID from the spec (`T01`, `T02`, …) |
| `config` | string | Configuration name as passed to `make sim CFG=<name>` |
| `seed` | integer or null | Seed used, or `null` if the test is not randomized |
| `status` | string | `PASS`, `FAIL` or `NOT_RUN` |
| `log` | string | Log path, relative to the repo root |

## `failures[]`

Each distinct failure is listed once, even if it fails in several configurations. Put the other configurations in `also_fails`.

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | `F01`, `F02`, … unique within the file. Numbering restarts every round |
| `test` | string | yes | Failing test ID, or `LINT` for an issue found by the independent linter |
| `config` | string | yes | First configuration that fails |
| `seed` | integer or null | yes | Seed that reproduces it |
| `also_fails` | array of strings | no | Other configurations with the same failure |
| `class` | string | yes | `rtl`, `tb`, `spec` or `coverage` (below) |
| `requirements` | array of strings | yes | Requirement IDs involved (e.g. `["I2C-ENG-004"]`). At least one |
| `summary` | string | yes | One sentence: what is wrong |
| `evidence` | object | yes | `time` (sim time or cycle at first mismatch), `signals` (array), `expected`, `observed`, `log` (path). Any field can be `null` if not applicable |
| `proposed_fix` | string | yes | What the owner should change, citing the spec. For `spec`, the question that needs deciding |
| `files` | array of strings | no | Files the fix is expected to touch |
| `approved` | boolean | yes | Always written as `false`. Only the user changes it (`flow.sh approve`) |

### Classes

| `class` | Meaning | Who fixes it in `flow.sh fix` |
|---|---|---|
| `rtl` | The RTL disagrees with the spec | RTL session |
| `tb` | The testbench disagrees with the spec | TB session |
| `coverage` | A coverage target is not met; `proposed_fix` names the stimulus or exclusion | TB session |
| `spec` | The spec is ambiguous or silent | Nobody. `flow.sh` stops; the spec goes back through `md-revision` |

## `coverage[]`

| Field | Type | Meaning |
|---|---|---|
| `metric` | string | `functional`, `line`, `branch` or `toggle` |
| `config` | string | Configuration name |
| `result` | number | Percentage achieved |
| `target` | number | Target percentage (from the spec, or the `NEX.md` defaults) |
| `met` | boolean | `result >= target` after exclusions |
| `exclusions` | array | `{"item": string, "reason": string}` for each excluded item |

Every unmet coverage target must also appear in `failures[]` with `class: "coverage"`, so that `flow.sh fix` can act on it.

## Rules `flow.sh` enforces

- The file must parse as JSON and contain every required field.
- `round` must match the round `flow.sh` asked for, and `summary` must match the counts in `results`.
- `class` must be one of the four values; `id`s must be unique.
- Every entry in `failures[]` must start with `approved: false`.
- If `failures[]` is empty but `summary.fail > 0`, or any coverage entry has `met: false`, the file is rejected.
- If `failures[]` is empty and the file passes, `flow.sh` runs `make regress` once itself and trusts its exit code over the file.

## Example

See `triage.example.json`.
