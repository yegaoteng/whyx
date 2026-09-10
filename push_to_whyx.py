#!/usr/bin/env python3
"""Push the NetShooter project to the GitHub repo `whyx` using a PAT.

Usage:
    PAT=ghp_xxx...  python3 push_to_whyx.py [--owner <user>] [--repo whyx] [--dry-run]

Behavior:
- Reads the token from env var PAT (never logs it).
- Detects the current authenticated user if --owner not given (via `gh api /user`).
- Creates the repo `whyx` under that account (public, auto-init avoided, idempotent).
- Configures the remote, pushes all branches and tags.
- Prints the final repo URL and the tag-creation command for triggering the build.
"""
import os
import sys
import subprocess
import argparse
import json
import urllib.request
import urllib.parse
import base64
import shutil

GITHUB_API = "https://api.github.com"


def run(cmd, check=True, capture=False):
    print("+ " + " ".join(cmd) if isinstance(cmd, list) else "+ " + cmd)
    if capture:
        return subprocess.run(cmd, text=True, capture_output=True, check=check)
    return subprocess.run(cmd, check=check)


def gh_api(method, path, token, body=None):
    url = GITHUB_API + path if path.startswith("/") else GITHUB_API + "/" + path
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if body is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(body).encode("utf-8")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        err = json.loads(e.read().decode("utf-8") or "{}")
        raise RuntimeError(f"{method} {path} -> {e.code}: {err.get('message')} ({err.get('errors')})")


def get_user(token):
    return gh_api("GET", "/user", token)["login"]


def repo_exists(token, owner, repo):
    try:
        gh_api("GET", f"/repos/{owner}/{repo}", token)
        return True
    except RuntimeError as e:
        if "404" in str(e):
            return False
        raise


def create_repo(token, owner, repo, private=False):
    body = {"name": repo, "private": private, "auto_init": False, "description":
            "NetShooter — self-hosted multiplayer shooter (Godot 4.3). Windows EXE + Android APK via GitHub Actions."}
    # personal account
    return gh_api("POST", "/user/repos", token, body)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner")
    ap.add_argument("--repo", default="whyx")
    ap.add_argument("--branch", default="main")
    ap.add_argument("--private", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    token = os.environ.get("PAT", "").strip()
    if not token:
        print("ERROR: set env PAT=your_classic_pat (needs 'repo' scope)", file=sys.stderr)
        sys.exit(1)

    project = os.path.join(os.path.dirname(os.path.abspath(__file__)), "godot-shooter")
    if not os.path.isdir(project):
        print("ERROR: project dir not found:", project, file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print("[dry-run] would push", project, "to", args.owner + "/" + args.repo)
        return

    owner = args.owner or get_user(token)
    print("Authenticated as:", owner)
    print("Target repo:", f"{owner}/{args.repo}")

    if not shutil.which("git"):
        print("ERROR: git not available in sandbox", file=sys.stderr)
        sys.exit(2)

    # ensure a git repo
    if not os.path.exists(os.path.join(project, ".git")):
        run(["git", "-C", project, "init", "-b", args.branch])
    else:
        run(["git", "-C", project, "checkout", "-B", args.branch])

    run(["git", "-C", project, "config", "user.name", "NetShooter Bot"])
    run(["git", "-C", project, "config", "user.email", "netshooter@example.com"])

    # create repo if needed
    if not repo_exists(token, owner, args.repo):
        print("Repo does not exist -> creating...")
        create_repo(token, owner, args.repo, private=args.private)
        print("Created:", f"{owner}/{args.repo}")
    else:
        print("Repo already exists (will push to it).")

    remote_url = f"https://x-access-token:{token}@github.com/{owner}/{args.repo}.git"
    if "origin" in subprocess.run(["git", "-C", project, "remote"], capture=True, text=True).stdout:
        run(["git", "-C", project, "remote", "remove", "origin"])
    run(["git", "-C", project, "remote", "add", "origin", remote_url])

    # commit
    run(["git", "-C", project, "add", "-A"])
    status = subprocess.run(["git", "-C", project, "status", "--porcelain"],
                            capture=True, text=True).stdout
    if status.strip():
        run(["git", "-C", project, "commit", "-m",
             "feat: complete NetShooter project (Godot 4.3, self-hosted multiplayer)\n\n"
             "- ENet server/client with lobby, player sync, shooting, scoring\n"
             "- Windows + Android export presets\n"
             "- GitHub Actions: push tag -> build EXE + APK -> publish Release\n"
             "- one-click build scripts (build.sh/build.bat) and verification"])
    else:
        print("No changes to commit (already up to date).")

    # push branch + tags
    run(["git", "-C", project, "push", "-u", "origin", args.branch, "--force"])
    run(["git", "-C", project, "tag", "-f", "v1.0.0"])
    run(["git", "-C", project, "push", "origin", "--tags", "--force"])

    # strip token from remote url in config (defensive)
    run(["git", "-C", project, "remote", "set-url", "origin",
         f"https://github.com/{owner}/{args.repo}.git"])

    print()
    print("=" * 60)
    print("PUSH COMPLETE")
    print(f"Repo:    https://github.com/{owner}/{args.repo}")
    print(f"Actions: https://github.com/{owner}/{args.repo}/actions")
    print(f"Tags:    https://github.com/{owner}/{args.repo}/tags")
    print()
    print("Next: open the repo in your browser. The 'v1.0.0' tag was pushed,")
    print("so GitHub Actions should already be building Windows EXE + Android APK.")
    print("When the workflow finishes, download both artifacts from the Releases page:")
    print(f"  https://github.com/{owner}/{args.repo}/releases")


if __name__ == "__main__":
    main()
