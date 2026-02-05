---
name: ralph-manager
description: Orchestrate iterative development with an autonomous coding agent. Breaks plans into kanban tasks, manages iterations via CLI, tracks progress on a live dashboard, and handles the branch-iterate-commit-squash workflow.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# Ralph Manager

## Overview

Manage Ralph (OpenCode agent) to execute complex projects through iterative development with full git integration.

**Key Principles:**
- `ralph.json` is sacred — treat it as ground truth
- Dashboard runs independently (from skill, not repo)
- Git workflow: branch → iterate+commit → verify → squash PR

---

## First-Time Setup

Run once after installing the skill:

```bash
~/.openclaw/skills/ralph-manager/scripts/setup.sh
```

This installs Python deps (flask, flask-cors), creates the `ralph` CLI symlink in `~/.local/bin/`, and verifies system dependencies.

**System dependencies** (must be installed separately):
- `python3`, `tmux`, `git` — core requirements
- `opencode` — Ralph agent runtime

---

## File Structure

```
~/.openclaw/skills/ralph-manager/
├── SKILL.md                    # This file (main instructions)
├── CLI.md                      # CLI reference (full command docs)
├── scripts/
│   ├── setup.sh                # First-time setup (run once)
│   ├── ralph-cli               # CLI for managing ralph.json (use instead of manual edits)
│   ├── dashboard.py            # Flask server (port 5000)
│   ├── static/
│   │   └── index.html          # Dashboard UI
│   ├── start-dashboard.sh      # Tmux starter (takes ralph.json path as arg)
│   └── requirements.txt        # Python deps
└── ralph.schema.json           # JSON schema for validation

{repo}/                         # Project repository
├── ralph.json                  # Kanban (sacred, I manage this)
├── plan.md                     # Your input (source of truth)
└── .git/                       # Git repo
```

**Critical:** Dashboard runs from skill folder, never touches repo except via `ralph.json`.

---

## ralph.json Schema

Located at repo root. Both dashboard and Ralph read this.

```json
{
  "project": "name",
  "repo": "/absolute/path",
  "status": "initialized|running|paused|completed",
  "branch": "ralph/feat-name",
  "base_branch": "main",
  "iterations": {"planned": 10, "actual": 0},
  "current": {
    "id": 1,
    "task": "Short task title (1 line)",
    "description": "Detailed context: what to build, architecture, implementation details, edge cases, dependencies...",
    "status": "in_progress",
    "started_at": "2026-02-03T08:00:00Z",
    "retries": 0,
    "skills": ["ui"],
    "acceptance": ["criteria"]
  },
  "completed": [
    {
      "id": 0,
      "task": "...",
      "description": "...",
      "completed_at": "...",
      "retries": 0,
      "commit": "abc123",
      "files_changed": [],
      "test_results": "pass"
    }
  ],
  "backlog": [
    {
      "id": 2,
      "task": "Short title",
      "description": "Full context for Ralph when this task becomes current",
      "depends_on": [1],
      "skills": ["typescript"],
      "acceptance": ["criteria"]
    }
  ],
  "discovered": [],
  "notes": []
}
```

### Task Fields Explained

- **`task`** (string, 1 line): Short, human-readable title. Appears in kanban card.
- **`description`** (string, multi-line): **Full technical context.** This is what Ralph reads. Include: what to build, architecture decisions, implementation approach, file paths, edge cases, dependencies, references.
- **`skills`** (array): Skills Ralph should use (typescript, react, nextjs, etc.)
- **`acceptance`** (array): Criteria for "done" - Ralph runs tests to verify these
- **`retries`** (number, default 0): How many times the supervisor re-fired Ralph on this task. Supervisor increments before each retry. Carries over to completed. Dashboard flags tasks with retries > 0.
- **`depends_on`** (array of task IDs, backlog only): Tasks that must complete before this one can start. Set once during planning, never updated by Ralph. Dashboard shows blocked tasks as dimmed.

---

## Complete Workflow

### Step 1: Init
**Trigger:** User says "Ralph this repo"

**Actions:**
1. Run `setup.sh` if first time (checks deps, installs flask, creates symlink)
2. Read `plan.md`
3. Bootstrap kanban:
   ```bash
   export RALPH_JSON={repo}/ralph.json
   ralph init --project "name" --repo "{repo}" --iterations 10
   ```
4. Break plan into tasks — add each via CLI:
   ```bash
   echo "Full task description..." | ralph task add --id 0 --title "Task name" --skills "ts,react" --depends-on "1,2"
   ```
5. Start dashboard: `~/.openclaw/skills/ralph-manager/scripts/start-dashboard.sh {repo}/ralph.json`
6. Send plan to user for approval

**Task Sizing Rule:**
- Err on side of SMALL
- If might overflow context → split into 2
- Prefer trivial over risky
- Every task fits in ONE Ralph session

**Writing Good Task Descriptions:**

The `description` field is what Ralph actually reads. Make it comprehensive:

```json
{
  "task": "Create auth middleware",
  "description": "Implement JWT authentication middleware for Next.js API routes.\n\nWhat to build:\n- Middleware at middleware.ts that checks for JWT in Authorization header\n- Should protect routes under /api/protected/*\n- Allow public access to /api/auth/*\n\nImplementation:\n- Use jose library for JWT verification (already installed)\n- Read JWT_SECRET from env\n- Decode token, check exp, attach user to request\n- Return 401 if token missing/invalid\n\nEdge cases:\n- Handle missing Authorization header gracefully\n- Handle malformed tokens\n- Handle expired tokens\n\nTesting:\n- Create tests at __tests__/middleware.test.ts\n- Test valid token, missing token, expired token, malformed token\n\nRelated:\n- Login endpoint creates tokens at /api/auth/login\n- User type defined in lib/types/user.ts"
}
```

**Description should include:**
- What to build (high level)
- Specific implementation details (libraries, file paths)
- Edge cases to handle
- Testing requirements
- Related files/context
- Any architectural decisions

---

### Step 2: Green Light + Branch
**Trigger:** User approves PDF

**Actions:**
1. `cd {repo}`
2. `git checkout -b ralph/{project-name}`
3. Update `ralph.json` with branch name
4. Start dashboard (if not running)

---

### Step 3: Iteration Loop

**Per Iteration:**

#### A. Update ralph.json First
```bash
ralph task start {next_id}    # Moves backlog → current (validates depends_on, sets retries: 0, auto-timestamps)
ralph iter                    # Increment iteration counter
```

#### B. Fire Ralph

**New Architecture:** Task carries full context. Command is minimal.

```bash
cd {repo} && opencode run --title "Iter {n}: {task.title}" "
You are Ralph, an autonomous coding agent.

SETUP:
export RALPH_JSON={repo}/ralph.json
alias ralph='python3 ~/.openclaw/skills/ralph-manager/scripts/ralph-cli'

RULES:
1. Run: ralph show (to see current task)
2. Do ONLY the current task
3. Write tests for your changes
4. Run ALL tests - must pass
5. Run linter - fix all errors
6. Run: ralph task complete --test pass --files 'file1.ts,file2.ts' --next {next_id}
7. If you discover new issues: echo 'description' | ralph discover --id {new_id} --title 'Issue title' --source 'Task #{current_id}'
8. Use skills: {skills}
9. Terminate when done

CURRENT TASK:
{task.description}

ACCEPTANCE CRITERIA:
{task.acceptance.join('\n')}

Begin."
```

**Key Points:**
- **Ralph uses `ralph-cli`** for all ralph.json updates — no manual JSON editing
- **`task complete --next`** completes current + starts next in one atomic command
- **Timestamps are automatic** — CLI handles `started_at` and `completed_at`
- **Description not needed in command** — already in ralph.json, CLI preserves it

#### C. Ralph Works
- Runs `ralph show` to see current task
- Does the task
- Runs tests + lint
- Runs `ralph task complete --test pass --files "..." --next {next_id}`
- Runs `ralph discover ...` if new issues found
- Exits

#### D. I Review
1. Run `ralph show` to check state
2. Check test results in Ralph's output
3. If tests pass → proceed to commit
4. If tests fail → `ralph task retry` then re-fire Ralph (same task)

#### E. Commit
```bash
cd {repo}
git add -A
git commit -m "{project}: {task_description}

- {what was done}
- Tests: {pass/fail}
- Iteration: {n}/{total}"

ralph commit {hash}           # Attach commit hash to last completed task
```

#### F. Next Iteration
1. `ralph task start {next_id}` (respects `depends_on`, auto-sets `retries: 0`)
2. Repeat from Step 3A

---

### Step 4: Complete + Verify

**When all tasks done:**

#### A. Functional Verification
```bash
# Start dev server
cd {repo} && npm run dev

# Use agent-browser skill
canvas present http://localhost:3000
# Or playwright for automated checks
```

**Take screenshots** → Send to user

#### B. User Review
User checks screenshots/actual site

**If issues found:**
- Add tasks to backlog
- Run more iterations
- Commit fixes

**If all good:**
Proceed to squash

#### C. Squash + PR
```bash
cd {repo}
git checkout {base_branch}
git merge --squash ralph/{project-name}
git commit -m "feat: {project_description}"

# Or create PR
git push origin ralph/{project-name}
# Create PR via gh CLI or GitHub
```

#### D. Final Report
```
✓ Project: {name}
✓ Branch: ralph/{name} → {base_branch}
Iterations: {actual}/{planned}
Commits: {list}
Tests: All passing
Verification: Screenshots attached
Status: Complete
```

---

## Dashboard

**Purpose:** Read-only monitoring of `ralph.json`

**Start:**
```bash
~/.openclaw/skills/ralph-manager/scripts/start-dashboard.sh /path/to/ralph.json
```

The script takes the ralph.json path as an argument (or reads `RALPH_JSON` env var). It handles the tmux session and passes the path to the Flask server.

**If dashboard shows nothing:**
- Verify ralph.json exists at the path you passed
- Check `curl http://localhost:5000/api/status` returns data

**Access:** http://localhost:5000

**Features:**
- Real-time kanban (polls every 2s)
- Progress bar
- Current task highlight
- **Tap/Click any task to see full description** — shows the detailed context that Ralph receives
- Scroll position preserved on updates
- Mobile responsive

**Stop:** `tmux kill-session -t ralph-dashboard`

---

## Test Requirements

Every iteration MUST:
1. Write tests for the task
2. Run tests — ALL pass
3. Run linter — no errors

**Framework detection:**
- `vitest.config.*` → Vitest
- `jest.config.*` → Jest
- `pytest.ini` or `test_*.py` → Pytest
- `Cargo.toml` with [dev-dependencies] → Cargo test

If no framework detected → ask user or configure one.

---

## Git Workflow Summary

```
main ──┬──► ralph/feat-auth ──► [iter1] ──► commit ──► [iter2] ──► commit ──► ...
       │                                                          │
       │                                                          ▼
       │                                                  verify + screenshots
       │                                                          │
       │◄──────────────────────────────────────────────── squash ─┘
       │
       ▼
   git merge --squash
```

---

## Error Handling

| Issue | Action |
|-------|--------|
| Tests fail | Increment `current.retries`, re-fire Ralph on same task |
| Ralph stuck | Abort session, increment retries, re-fire or add diagnostic task |
| Dependencies missing | Report to user, pause until resolved |
| Git conflict | Pause, notify user, manual resolution |
| Dashboard down | Restart via tmux, continue |

---

## Example Session

**User:** "Build auth system"

**Me:**
1. `ralph init --project "auth-system" --repo /home/user/app --iterations 8`
2. Break plan into tasks:
   ```bash
   echo "Create Prisma User model..." | ralph task add --id 0 --title "User model" --skills "prisma"
   echo "Implement Argon2 hashing..." | ralph task add --id 1 --title "Password hashing" --depends-on "0"
   echo "JWT token service..." | ralph task add --id 2 --title "JWT service" --depends-on "0"
   ```
3. `start-dashboard.sh /home/user/app/ralph.json`
4. User approves plan
5. `git checkout -b ralph/auth-system` → `ralph status running`
6. **Iter 1:** `ralph task start 0` → `ralph iter` → fire Ralph → tests pass → `git commit` → `ralph commit abc123`
7. **Iter 2:** `ralph task start 1` → `ralph iter` → fire Ralph → tests pass → `git commit` → `ralph commit def456`
8. **Iter 3:** `ralph task start 2` → `ralph iter` → fire Ralph → tests fail → `ralph task retry` → re-fire → pass → `git commit`
9. ...continue...
10. All done → verify with screenshots → user approves
11. `git checkout main && git merge --squash ralph/auth-system`
12. Final report

---

## CLI — `ralph-cli`

**Use the CLI for all ralph.json mutations.** Saves tokens, handles timestamps, validates deps, atomic writes.

Full reference: [CLI.md](CLI.md)

**Essential commands:**

```bash
ralph init --project "name" --repo "/path" --iterations 10   # Bootstrap ralph.json
ralph show                                                    # Project summary
ralph task start 5                                            # Backlog → current
ralph task complete --test pass --files "a.ts,b.ts" --next 6  # Complete + start next
ralph task retry                                              # Increment retries
ralph iter                                                    # Increment iteration counter
ralph commit abc123                                           # Attach commit hash
echo "Description" | ralph task add --id 11 --title "Task"    # Add to backlog
echo "Description" | ralph discover --id 12 --title "Issue"   # Add discovered
ralph note "Important note"                                   # Append note
ralph task promote 9                                          # Discovered → backlog
```

---

## Key Reminders

- `ralph.json` is sacred — update it via `ralph-cli`, not manual edits
- **Use CLI for all kanban operations** — saves tokens, prevents malformed JSON
- **Only edit ralph.json directly** for task description changes (rare)
- **Task `description` is Ralph's context** — write comprehensive, technical descriptions
- **Tap tasks in dashboard** to see full descriptions (verify what Ralph will read)
- Dashboard is independent — runs from skill folder
- Commit after every successful iteration
- Tests must pass before commit
- Verify with screenshots before squash
