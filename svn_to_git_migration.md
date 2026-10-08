# SVN to Git Migration Guide

## Purpose

This guide describes how to migrate **one SVN project to Git/Forgejo** on a Debian 13 server named `reposerver`.

The migration is designed to be **non-destructive**:

- The existing SVN repository is **read-only during migration**.
- The SVN project remains intact.
- A temporary Git repository is created on `reposerver`.
- The converted Git repository is pushed to Forgejo.
- The SVN repository can remain available for verification or rollback.

---

## 1. Migration overview

The migration looks like this:

```text
                    READ ONLY
┌───────────────────────┐
│      SVN Server       │
│                       │
│   existing project    │
└───────────┬───────────┘
            │
            │ git svn clone
            ▼
┌───────────────────────────────┐
│          reposerver            │
│          Debian 13             │
│                                │
│  temporary Git-SVN repository  │
└──────────────┬────────────────┘
               │
               │ git push
               ▼
┌───────────────────────────────┐
│            Forgejo             │
│                                │
│       new Git repository       │
└───────────────────────────────┘
```

The original SVN project is never modified by `git svn clone`.

---

# 2. Prerequisites

You need:

- A Debian 13 server called `reposerver`.
- Working Git and Forgejo access on `reposerver`.
- Network access from `reposerver` to the SVN server.
- Read access to the SVN project.
- Permission to create a new repository in Forgejo.
- Sufficient disk space for the converted repository and its history.

Recommended:

- Know the SVN project layout (`trunk`, `branches`, `tags`, etc.).
- Have a list of SVN usernames and their corresponding Git names/email addresses.
- Perform the migration while no important SVN changes are being made.

---

# 3. Install Git-SVN on reposerver

Log in to `reposerver` and install the required package:

```bash
sudo apt update
sudo apt install git git-svn
```

Verify the installation:

```bash
git --version
git svn --version
```

Both commands should return version information.

---

# 4. Inspect the SVN project first

Before migrating anything, inspect the SVN project.

For example:

```bash
svn info svn://oldserver/repos/myproject
```

and:

```bash
svn ls svn://oldserver/repos/myproject
```

A typical standard SVN project looks like:

```text
branches/
tags/
trunk/
```

For example:

```text
myproject/
├── branches/
├── tags/
└── trunk/
```

If this is the layout, the `--stdlayout` option can normally be used.

## Important

Do **not** assume the layout.

If the project instead looks like:

```text
README
src/
docs/
Makefile
```

then it is not a standard `trunk/branches/tags` layout and the migration command needs to be adjusted.

---

# 5. Create a temporary migration directory

On `reposerver`:

```bash
mkdir -p ~/svn-migration
cd ~/svn-migration
```

The migration repository will be created here.

For example:

```text
~/svn-migration/
└── myproject/
```

---

# 6. Prepare SVN author mapping

This step is strongly recommended if the SVN history should have correct Git authors.

SVN often stores commits using usernames such as:

```text
jdoe
asmith
bob
```

Git should ideally contain proper identities such as:

```text
John Doe <john@example.com>
Alice Smith <alice@example.com>
Bob Smith <bob@example.com>
```

Create an author mapping file:

```bash
nano ~/svn-migration/authors.txt
```

Example:

```text
jdoe = John Doe <john@example.com>
asmith = Alice Smith <alice@example.com>
bob = Bob Smith <bob@example.com>
```

The format is:

```text
SVN_USERNAME = Full Name <email@example.com>
```

You can identify SVN authors with:

```bash
svn log -q svn://oldserver/repos/myproject
```

Look for all unique usernames.

---

# 7. Create the author conversion script

`git svn` expects an executable program for `--authors-prog`.

Create:

```bash
nano ~/svn-migration/authors.sh
```

Put the following in it:

```bash
#!/bin/sh

AUTHORS_FILE="$HOME/svn-migration/authors.txt"

if grep -q "^$1 =" "$AUTHORS_FILE"; then
    grep "^$1 =" "$AUTHORS_FILE" | sed 's/^[^=]*= //'
    exit 0
fi

echo "ERROR: SVN author '$1' is missing from $AUTHORS_FILE" >&2
exit 1
```

Make it executable:

```bash
chmod +x ~/svn-migration/authors.sh
```

Test it:

```bash
~/svn-migration/authors.sh jdoe
```

Expected result:

```text
John Doe <john@example.com>
```

Test an unknown user:

```bash
~/svn-migration/authors.sh unknown
```

It should report an error. This is intentional: it prevents an unknown SVN author from silently receiving an incorrect Git identity.

---

# 8. Create the Git-SVN clone

## Standard SVN layout

If the SVN project contains:

```text
trunk/
branches/
tags/
```

run:

```bash
cd ~/svn-migration

git svn clone \
    --stdlayout \
    --authors-prog="$HOME/svn-migration/authors.sh" \
    svn://oldserver/repos/myproject \
    myproject
```

Replace:

```text
svn://oldserver/repos/myproject
```

with the actual SVN project URL.

Example:

```bash
git svn clone \
    --stdlayout \
    --authors-prog="$HOME/svn-migration/authors.sh" \
    svn://svnserver/repos/myproject \
    myproject
```

This operation can take a long time for projects with a large SVN history.

### Important

This command reads the SVN repository.

It does **not** delete, move, commit, or otherwise modify the SVN project.

---

# 9. Non-standard SVN layout

If the project does not have `trunk/branches/tags`, do not use `--stdlayout`.

For a simple SVN project:

```text
myproject/
├── README
├── src/
├── docs/
└── Makefile
```

the command is typically:

```bash
cd ~/svn-migration

git svn clone \
    --authors-prog="$HOME/svn-migration/authors.sh" \
    svn://oldserver/repos/myproject \
    myproject
```

Branch and tag handling for non-standard layouts needs to be evaluated separately.

---

# 10. Verify the converted repository

Enter the new Git repository:

```bash
cd ~/svn-migration/myproject
```

Check the working tree:

```bash
git status
```

You should normally see:

```text
On branch master
nothing to commit, working tree clean
```

or an equivalent clean status.

Inspect the history:

```bash
git log --oneline --decorate --graph --all
```

Inspect commit authors:

```bash
git log --format='%h %an <%ae>' --all
```

Inspect branches:

```bash
git branch -a
```

Inspect tags:

```bash
git tag
```

Check the number of commits:

```bash
git rev-list --all --count
```

---

# 11. Check the SVN history against Git

It is useful to compare the SVN and Git history.

SVN:

```bash
svn log -q svn://oldserver/repos/myproject
```

Git:

```bash
git log --all --format='%h %ad %an %s' --date=short
```

The exact presentation will differ, but the important thing is that the historical commits are present.

For a critical project, inspect several known SVN revisions manually and verify:

- author
- date
- commit message
- changed files
- file contents

---

# 12. Create an empty repository in Forgejo

Create a new repository in Forgejo.

For example:

```text
myproject
```

For the cleanest migration, the new Forgejo repository should be **empty**.

Do not initialize it with:

- README
- `.gitignore`
- license
- initial commit

The repository should contain no Git commits before the migration.

For example, Forgejo may provide an SSH URL similar to:

```text
ssh://git@reposerver/myuser/myproject.git
```

Use the actual URL provided by your Forgejo installation.

---

# 13. Add Forgejo as the Git remote

From the converted repository:

```bash
cd ~/svn-migration/myproject
```

Check the existing remotes:

```bash
git remote -v
```

Add the Forgejo repository:

```bash
git remote add origin ssh://git@reposerver/myuser/myproject.git
```

Verify:

```bash
git remote -v
```

Expected:

```text
origin  ssh://git@reposerver/myuser/myproject.git (fetch)
origin  ssh://git@reposerver/myuser/myproject.git (push)
```

---

# 14. Push the Git repository to Forgejo

First determine the current branch:

```bash
git branch --show-current
```

If it is `master`, push it:

```bash
git push -u origin master
```

If you want the Git default branch to be `main`:

```bash
git branch -M main
git push -u origin main
```

Then push tags:

```bash
git push origin --tags
```

If branches were imported as local Git branches, inspect them first:

```bash
git branch -a
```

Push any branches that should exist in Forgejo.

For example:

```bash
git push origin branch-name
```

---

# 15. Verify the Forgejo repository

Open the new repository in Forgejo and verify:

- Files are present.
- Commit history is present.
- Authors are correct.
- Dates look correct.
- Commit messages are correct.
- Tags are present.
- Required branches are present.

You can also perform an independent clone:

```bash
cd /tmp

git clone ssh://git@reposerver/myuser/myproject.git test-myproject
```

Then:

```bash
cd test-myproject
```

Check:

```bash
git status
git log --oneline --decorate --graph --all
git tag
```

This verifies that the repository can actually be cloned from Forgejo.

---

# 16. Verify that SVN is still intact

The original SVN repository should still be fully available.

Run:

```bash
svn info svn://oldserver/repos/myproject
```

and:

```bash
svn ls svn://oldserver/repos/myproject
```

You can also inspect the latest SVN revision:

```bash
svn log -l 5 svn://oldserver/repos/myproject
```

The SVN repository should be unchanged.

## Critical point

The migration commands use SVN as the **source**.

They do not perform an SVN commit.

Therefore, the SVN repository remains intact.

---

# 17. Recommended migration procedure for production

For an important project, use this sequence:

```text
1. Inspect SVN
        │
        ▼
2. Create author mapping
        │
        ▼
3. Clone SVN with git-svn
        │
        ▼
4. Verify Git history
        │
        ▼
5. Create empty Forgejo repository
        │
        ▼
6. Push Git repository
        │
        ▼
7. Independently clone from Forgejo
        │
        ▼
8. Verify files/history/tags/branches
        │
        ▼
9. Keep SVN available as the original
```

Do not delete or disable SVN until the Git repository has been thoroughly verified.

---

# 18. Optional: freeze SVN during final migration

If the SVN project is actively changing, there is a potential consistency problem:

```text
10:00  git svn clone starts
10:30  someone commits to SVN
11:00  migration finishes
```

The Git repository then represents the SVN repository as of the migration point, not necessarily the latest state.

For the final migration, it is therefore recommended to temporarily stop SVN commits.

A typical procedure is:

```text
1. Announce migration window.
2. Stop/disable SVN writes.
3. Perform final git-svn migration.
4. Push to Forgejo.
5. Verify Git.
6. Announce Git as the new development repository.
7. Keep SVN available read-only for historical/reference purposes.
```

The exact method for making SVN read-only depends on how the SVN server is configured.

---

# 19. Optional: perform a final SVN update

If SVN was changing during an initial test migration, you can update the Git-SVN repository before the final push.

From the migration repository:

```bash
git svn fetch
```

Then inspect:

```bash
git log --oneline --all --decorate --graph
```

For a normal SVN-to-Git migration, do the final conversion from a clean, controlled SVN state rather than relying on an old test clone.

---

# 20. Useful verification commands

## Git working tree

```bash
git status
```

## Git branches

```bash
git branch -a
```

## Git tags

```bash
git tag
```

## Git commit count

```bash
git rev-list --all --count
```

## Git history

```bash
git log --oneline --decorate --graph --all
```

## Git authors

```bash
git log --format='%h %an <%ae>' --all
```

## SVN information

```bash
svn info svn://oldserver/repos/myproject
```

## SVN recent history

```bash
svn log -l 20 svn://oldserver/repos/myproject
```

## SVN directory structure

```bash
svn ls svn://oldserver/repos/myproject
```

---

# 21. Common mistakes to avoid

## Do not initialize Forgejo with a README

Avoid creating:

```text
README.md
```

as an initial Forgejo commit.

The imported Git history should be the repository's initial history.

---

## Do not run `git push --force` unless you understand why

Normally the first push to an empty Forgejo repository does not require force.

Use:

```bash
git push -u origin main
```

or:

```bash
git push -u origin master
```

---

## Do not use `--stdlayout` blindly

Only use:

```bash
--stdlayout
```

when the SVN project actually uses:

```text
trunk/
branches/
tags/
```

---

## Do not delete the SVN project immediately

Keep the original SVN repository available until the Git migration has been validated.

For example:

```text
SVN
 └── original project
       │
       ├── keep during migration
       ├── verify Git
       └── retain as historical backup/reference
```

---

## Do not forget SVN authors

An incomplete author mapping can result in failed migration or incorrect commit identities.

Make sure every SVN username appearing in the history is mapped.

---

# 22. Example complete migration

Assume:

```text
SVN server: svnserver
SVN project: svn://svnserver/repos/myproject

Forgejo server: reposerver
Forgejo user: myuser
Forgejo repository: myproject
```

Create the migration directory:

```bash
mkdir -p ~/svn-migration
cd ~/svn-migration
```

Create:

```text
~/svn-migration/authors.txt
```

Example:

```text
jdoe = John Doe <john@example.com>
asmith = Alice Smith <alice@example.com>
```

Create:

```text
~/svn-migration/authors.sh
```

with:

```bash
#!/bin/sh

AUTHORS_FILE="$HOME/svn-migration/authors.txt"

if grep -q "^$1 =" "$AUTHORS_FILE"; then
    grep "^$1 =" "$AUTHORS_FILE" | sed 's/^[^=]*= //'
    exit 0
fi

echo "ERROR: SVN author '$1' is missing from $AUTHORS_FILE" >&2
exit 1
```

Make it executable:

```bash
chmod +x ~/svn-migration/authors.sh
```

Clone the SVN project:

```bash
git svn clone \
    --stdlayout \
    --authors-prog="$HOME/svn-migration/authors.sh" \
    svn://svnserver/repos/myproject \
    myproject
```

Enter the repository:

```bash
cd ~/svn-migration/myproject
```

Verify:

```bash
git status
git log --oneline --decorate --graph --all
git branch -a
git tag
```

Add Forgejo:

```bash
git remote add origin ssh://git@reposerver/myuser/myproject.git
```

Push:

```bash
git push -u origin master
git push origin --tags
```

Or, if using `main`:

```bash
git branch -M main
git push -u origin main
git push origin --tags
```

Finally, clone the Forgejo repository independently:

```bash
cd /tmp
git clone ssh://git@reposerver/myuser/myproject.git verify-myproject
cd verify-myproject

git status
git log --oneline --decorate --graph --all
git tag
```

At this point you have:

```text
SVN
└── myproject
    └── ORIGINAL, UNMODIFIED

Forgejo
└── myproject
    └── MIGRATED GIT REPOSITORY
```

---

# 23. Final checklist

Before considering the migration complete, verify:

- [ ] `git-svn` is installed.
- [ ] SVN project layout has been identified.
- [ ] SVN usernames have been mapped.
- [ ] `git svn clone` completed successfully.
- [ ] Git working tree is clean.
- [ ] Git commit history is present.
- [ ] Git authors are correct.
- [ ] Git branches have been checked.
- [ ] Git tags have been checked.
- [ ] Empty Forgejo repository was created.
- [ ] Git repository was pushed to Forgejo.
- [ ] Forgejo repository can be independently cloned.
- [ ] Files in Forgejo are correct.
- [ ] History in Forgejo is correct.
- [ ] Tags in Forgejo are correct.
- [ ] Required branches in Forgejo are correct.
- [ ] Original SVN repository is still accessible.
- [ ] SVN project has not been modified or deleted.
- [ ] Developers have been told which repository is now authoritative.

---

# 24. Recommended end state

After a successful migration, a good arrangement is:

```text
                    ┌──────────────────────┐
                    │      SVN Server      │
                    │                      │
                    │  Original project    │
                    │  READ-ONLY           │
                    └──────────┬───────────┘
                               │
                         historical
                         reference
                               │
                               │
                    ┌──────────▼───────────┐
                    │      reposerver       │
                    │       Forgejo         │
                    │                       │
                    │   myproject.git       │
                    │   PRIMARY repository  │
                    └───────────────────────┘
```

The SVN repository can be retained as a historical reference while all new development takes place in Git/Forgejo.

---

## Important safety principle

**Do not perform any SVN write operation as part of this migration.**

The migration should be based on:

```text
SVN --read--> git-svn --convert--> Git --push--> Forgejo
```

and never:

```text
SVN <--write-- Git
```

This keeps the original SVN project intact.
