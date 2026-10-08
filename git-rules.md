## Git for ex-SVN developers

### Mental model (the short version)

- There is no central "server copy". Every checkout is a full local repository.
- `svn commit` = commit + push in one step. Git splits that into two:
  - `git commit` — records the change **locally only**, nobody else can see it.
  - `git push` — publishes it to the remote.
- `svn up` → `git pull`
- SVN has no local branches. Git branches are cheap local pointers — use one per task instead of `svn:export` tricks.

### Daily commands

| Task | Git | SVN equivalent |
|---|---|---|
| Get the repo | `git clone <url>` | `svn checkout` |
| What changed? | `git status`, `git diff` | `svn status`, `svn diff` |
| Stage + commit | `git add -A && git commit -m "..."` | `svn commit` |
| Publish | `git push` | (included in `svn commit`) |
| Update | `git pull` | `svn update` |
| Undo local edits | `git restore <file>` | `svn revert` |
| History | `git log --oneline` | `svn log` |

### Stage → commit → push, in plain terms

Three steps, and SVN only ever showed you the last one:

```bash
git status                 # "what am I about to commit?" (like svn status)
git add -A                 # 1. STAGE: put changes in the "next commit" box
git commit -m "msg"        # 2. COMMIT: freeze them into history — LOCAL ONLY
git push                   # 3. PUSH: upload that history to the server
```

- **Stage** (`git add`) has no SVN equivalent. Think of it as picking which files go into the box. `git add -A` = "everything I changed". Forget it and your commit comes out empty.
- **Commit** is *not* shared. It's a local save point on your laptop.
- **Push** is what makes it visible to everyone. Do it often — unpushed commits die with your disk.

```bash
git add -A && git commit -m "Fix redirect after login" && git push
```

### `git stash` — park your half-done work

SVN's `svn revert` destroys your edits. Git has a drawer: **stash** saves your working changes and hands you back a clean tree, so you can pull/switch without committing garbage. Nothing is lost, nothing is committed.

```bash
git stash                   # save all uncommitted changes, clean the tree
git pull                    # now safe: tree is clean
git stash pop               # put the changes back on top (and drop the stash)
git stash list              # see parked stashes
git stash apply             # put changes back but KEEP them in the stash
git stash drop              # throw a parked stash away
```

Rules of thumb: `pop` right after you're done so you don't forget what's in there. Stash is local-only — never a substitute for a commit you care about.

### The traps that bite SVN folks

1. **Forgetting `git add`** — a commit only includes what you staged. New/changed files must be `git add`ed first.
2. **Commits aren't shared until `push`** — a "committed" change exists only on your machine and is lost if the disk dies.
3. **Dirty working tree** — don't pull with uncommitted changes in the files that the pull touches; conflicts work differently than SVN's text merge. Just `git stash` (and later `git stash pop`) if you're mid-change.

### Golden rules

- Small, frequent commits with meaningful messages.
- One branch per feature/task: `git switch -c feature-x`.
- If something goes wrong: `git status` + `git log --oneline` tells you where you are.

### Team workflow: branch → push → PR → review → main

**Nothing lands in `main` directly.** Any change — bug fix, new feature, doc tweak — happens on its own branch, gets pushed, and is merged only after another developer approves the PR. Someone else always merges it (or enables auto-merge once approved).

```bash
git switch main && git pull                  # always start from up-to-date main
git switch -c fix/login-redirect             # 1. branch, named after the task/issue
# ... work, committing as you go ...
git add -A && git commit -m "Fix redirect after login"
git push -u origin fix/login-redirect       # 2. push all commits to that branch

gh pr create --fill                         # 3. open the PR against main
# link the issue in the body ("Closes #42") so it closes on merge
# 4. another developer reviews → approves / requests changes
#    you push more commits to the same branch; the PR updates automatically
gh pr merge 42 --squash                     # 5. after approval, merge into main
git switch main && git pull && git branch -d fix/login-redirect   # 6. clean up
```

Rules of thumb:

- One issue/task per branch, named `fix/…`, `feature/…` or `chore/…`.
- Push every commit before asking for review — reviewers work from the remote branch.
- CI runs on the PR; don't merge while checks are red.
- After merge, sync `main` and delete the branch.

### Branches & Pull Requests

#### Branches

```bash
git branch                     # list local branches (* = current)
git switch -c feature-x        # create branch feature-x and switch to it
git switch main                # switch back to main
git switch -c feature-x origin/feature-x   # track an existing remote branch
git branch -d feature-x        # delete a merged branch (git branch -D to force)
```

Typical flow:

```bash
git switch main
git pull                       # sync first
git switch -c feature/my-task  # one branch per task
# ... commit on the branch ...
git push -u origin feature/my-task   # first push: sets up tracking (-u)
```

#### Pull Request (GitHub / GitHub-CLI)

```bash
gh pr create --fill            # opens a browser/web form prefilled
# or fully from the terminal:
gh pr create --title "My feature" --body "What & why" --base main
gh pr view                     # show the open PR on your branch
gh pr list                     # list PRs
gh pr merge 42                 # merge PR #42 (add --squash to squash commits)
```

Prefer pushing the branch and using the URL the push output prints (`.../compare/main...feature-x?quick_create=1`) — GitHub suggests the PR button for you. `gh` just automates that.

