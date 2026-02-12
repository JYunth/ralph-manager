# Ralph Manager

**Stop burning tokens in your sleep.** Ralph Manager is an [OpenClaw](https://github.com/opencode-ai/openclaw) skill that turns a complex PRD into a kanban of bite-sized tasks, fires [OpenCode](https://github.com/opencode-ai/opencode) agent instances at each one, and gives you a live mission-control dashboard so you can actually watch things get built instead of praying 50 blind runs somehow converge.

```
PRD  ──→  ralph.json  ──→  opencode instances  ──→  dashboard at :5000
 you       the skill         one per task            watch it cook
write it   breaks it down    mindful dispatch         in real time
```

---

## Why This Exists

Autonomous coding agents are powerful, but firing one at a vague 200-line PRD and hoping for the best is a coin flip. You either wake up to a working feature or a pile of hallucinated files and 47 failed test runs — and you just burned a week of API credits finding out which.

Ralph Manager sits between you and the chaos:

1. **You** write a complex PRD (the hard, human part)
2. **The skill** decomposes it into a dependency-aware task graph stored in `ralph.json`
3. **OpenCode instances** get dispatched to each task with surgical context — just what they need, nothing more
4. **A dashboard** on `localhost:5000` shows you the entire board in real time: what's cooking, what's done, what's blocked, what got discovered along the way

No more blind runs. No more waking up to mystery diffs. No more re-running the same prompt 50 times because iteration 23 silently broke something.

---

## The Flow

### 1. You Write a PRD

This is the human step. You write a detailed plan — `plan.md` or whatever you call it — describing the feature, the architecture, the edge cases, the acceptance criteria. This is where the quality of your output is decided. Ralph Manager doesn't think for you; it operationalizes your thinking.

### 2. Invoke the Skill

When you invoke `ralph-manager` inside OpenClaw, the skill reads your PRD and breaks it into discrete, dependency-ordered tasks. Each task gets:

- A concise title
- A rich description with full implementation context (file paths, libraries, edge cases)
- Acceptance criteria
- Skill tags (e.g., `typescript`, `react`, `websockets`)
- Dependency links to other tasks

All of this lands in `ralph.json` — the single source of truth for the entire project. The skill also spins up the dashboard in a tmux session so you can monitor from the jump.

### 3. OpenCode Instances Get Dispatched

The skill fires an OpenCode agent at each task, one at a time, respecting the dependency graph. Each agent gets a tightly scoped prompt: just the current task description, acceptance criteria, and the `ralph` CLI commands it needs. No bloated context. No "here's the entire PRD, figure it out."

The agent works, writes code, writes tests, runs the test suite, runs the linter, and reports back via the CLI:

```bash
ralph task complete --test pass --files "lib/auth/jwt.ts,tests/auth.test.ts" --next 3
```

If tests fail, the supervisor retries. If the agent discovers an unexpected issue, it logs it:

```bash
echo "UTC leap seconds break trajectory math" | ralph discover --id 9 --title "Handle leap seconds" --source "Task #2"
```

Every iteration gets a git commit. Every task completion is atomic. Nothing is lost.

### 4. You Watch It Cook

The dashboard at `http://localhost:5000` polls `ralph.json` every 2 seconds and renders a full kanban board:

- **Telemetry strip** — iteration count, tasks done, backlog size, current branch
- **Progress track** — visual bar with per-task tick marks (green = done, cyan = active, gray = pending)
- **Kanban columns** — In Progress, Backlog, Discovered, Completed
- **Task cards** — click any card for full description, acceptance criteria, retry count, commit hash
- **Live signal** — green beacon when connected, red when offline

It's a dark-themed, responsive SPA with a mission-control aesthetic. Works on desktop, tablet, and mobile.

### 5. Squash and Ship

When all tasks are done and verified, squash-merge the feature branch to main:

```bash
git checkout main
git merge --squash ralph/your-feature
git commit -m "feat: the thing you built"
```

Clean history. One commit per feature. Done.

---

## Prerequisites

You need the following installed before using Ralph Manager:

| Dependency | What it's for |
|---|---|
| **[OpenClaw](https://github.com/opencode-ai/openclaw)** | Skill runtime — this is an OpenClaw skill |
| **[OpenCode](https://github.com/opencode-ai/opencode)** | The coding agent that executes tasks |
| **[tmux](https://github.com/tmux/tmux)** | Dashboard runs in a tmux session |
| **python3** | CLI and dashboard server |
| **git** | Branch management, commits, squash workflow |
| **pip** | Installs Flask dependencies (`flask`, `flask-cors`) |

### Install

1. Install the skill via OpenClaw:
   ```bash
   openclaw install ralph-manager
   ```

2. Run first-time setup:
   ```bash
   ~/.openclaw/skills/ralph-manager/scripts/setup.sh
   ```
   This checks your system dependencies, installs Python packages, and creates the `ralph` CLI symlink in `~/.local/bin/`.

---

## Project Structure

```
ralph-manager/
├── SKILL.md                    # Main workflow instructions (what OpenClaw reads)
├── CLI.md                      # CLI command reference
├── scripts/
│   ├── setup.sh                # First-time setup
│   ├── ralph-cli               # Python CLI — all state mutations go through here
│   ├── dashboard.py            # Flask server polling ralph.json
│   ├── start-dashboard.sh      # Tmux launcher for the dashboard
│   ├── requirements.txt        # flask, flask-cors
│   ├── static/
│   │   └── index.html          # Dashboard SPA (kanban + telemetry)
│   ├── demo-ralph.json         # Example ralph.json (orbital nav project)
│   └── ralph.schema.json       # JSON schema for validation
└── README.md
```

---

## ralph.json — The Sacred File

All project state lives in `ralph.json`. Never edit it by hand — use the `ralph` CLI. The file tracks:

- **Project metadata** — name, repo path, branch, status
- **Iterations** — planned vs. actual count
- **Current task** — what the agent is working on right now
- **Completed tasks** — with commit hashes, test results, files changed, retry counts
- **Backlog** — dependency-ordered queue of upcoming tasks
- **Discovered tasks** — issues found during execution (promotable to backlog)
- **Notes** — project-level context

Here's a taste from the included demo (an orbital navigation system):

```json
{
  "project": "ORION-7",
  "status": "running",
  "iterations": { "planned": 12, "actual": 5 },
  "current": {
    "id": 4,
    "task": "Implement telemetry stream parser",
    "skills": ["typescript", "websockets", "binary-protocols"],
    "retries": 1
  },
  "completed": [
    { "id": 0, "task": "Initialize project scaffold", "commit": "a1b2c3d", "test_results": "pass" },
    { "id": 1, "task": "Design orbital mechanics data model", "commit": "e4f5g6h", "test_results": "pass" },
    { "id": 2, "task": "Build trajectory computation engine", "commit": "i7j8k9l", "retries": 2 },
    { "id": 3, "task": "Create REST API for mission planning", "commit": "m0n1o2p", "test_results": "pass" }
  ],
  "backlog": [
    { "id": 5, "task": "Build 3D orbit visualizer", "depends_on": [4] },
    { "id": 6, "task": "Ground station pass predictor" },
    { "id": 7, "task": "Auth and role-based access" },
    { "id": 8, "task": "Mission timeline dashboard", "depends_on": [5, 6] }
  ],
  "discovered": [
    { "id": 9, "task": "Handle leap seconds in time conversion", "source": "Task #2" }
  ]
}
```

---

## CLI Quick Reference

```bash
export RALPH_JSON=/path/to/ralph.json

ralph init --project "auth-system" --repo /home/user/app --iterations 8
ralph show                                          # project summary
ralph status running                                # set project status
ralph task ls                                       # list all tasks by column
ralph task start 5                                  # move backlog → current
ralph task complete --test pass --files "a.ts,b.ts" --next 6
ralph task retry                                    # increment retries on current
ralph task promote 9                                # discovered → backlog
ralph commit abc123f                                # attach commit to last completed
ralph iter                                          # increment iteration counter
echo "description" | ralph task add --id 3 --title "New task" --skills "ts,react"
echo "description" | ralph discover --id 10 --title "Bug found" --source "Task #4"
ralph note "Important context for the project"
```

Full docs in [CLI.md](CLI.md).

---

## On top of the Primitive Ralph Methodology

If you've used the basic Ralph approach — firing a single agent at a task and hoping it lands — Ralph Manager is the structured layer on top. It takes the same core idea (autonomous agent does the coding) and adds:

- **Task decomposition** — one agent, one task, one context window. No overloaded prompts.
- **Dependency graphs** — tasks execute in the right order. The CLI enforces it.
- **State persistence** — `ralph.json` survives crashes, restarts, and your laptop dying. Pick up where you left off.
- **Retry logic** — failed tasks get retried with incremented counters, not restarted from scratch.
- **Discovery tracking** — agents find unexpected issues and log them formally. Nothing gets lost in terminal scrollback.
- **Commit traceability** — every completed task links to a git commit. You know exactly which code came from which task.
- **Live observability** — the dashboard means you don't have to tail logs or guess what's happening.

This is how you go from "Claude, build me an auth system" to a properly sequenced, tested, committed, and observable development pipeline.

---

## Contributing

This is a FOSS project and contributions are welcome. Some areas where help would be especially valuable:

- **Dashboard improvements** — better visualizations, task reordering via drag-and-drop, dark/light theme toggle
- **Parallel task execution** — tasks with no dependency conflicts could run concurrently in separate tmux panes
- **Agent provider support** — currently built around OpenCode, but the dispatch layer could be abstracted
- **Notification hooks** — Slack/Discord/webhook alerts on task completion or failure
- **Enhanced retry strategies** — smarter context augmentation on retry (e.g., include error logs from the failed attempt)
- **Test result parsing** — structured test output capture instead of pass/fail boolean
- **Schema migrations** — versioned ralph.json schema with migration tooling
- **Plugin system** — custom pre/post task hooks for project-specific validation

### How to Contribute

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/your-thing`)
3. Make your changes
4. Test with a real project (spin up a ralph.json, run the dashboard, dispatch some tasks)
5. Submit a PR

No bureaucracy. If it makes Ralph Manager better, it's welcome.

---

## License

MIT
