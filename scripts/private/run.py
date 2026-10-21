"""Only fixed status messages reach Actions; child output/file commands stay private."""
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import traceback
from store import Store, prefix, workdir, require


def main():
    os.umask(0o077)
    label, *command = sys.argv[1:]
    require(re.fullmatch(r"[a-z0-9_.-]+", label) and command, "Invalid operation")
    env = dict(os.environ)
    for name in ("GITHUB_STEP_SUMMARY", "GITHUB_ENV", "GITHUB_PATH", "GITHUB_STATE", "GITHUB_OUTPUT"):
        if name == "GITHUB_OUTPUT" and label == "plan":
            continue
        if name in env:
            env[name] = str(workdir() / (label + "-" + name.lower()))
    log = workdir() / (label + ".log")
    print("Private operation started; diagnostics are stored in R2.", flush=True)
    with log.open("wb") as output:
        child = subprocess.Popen(command, env=env, stdout=output, stderr=output, start_new_session=True)
        def stop(number, frame):
            if child.poll() is None:
                os.killpg(child.pid, number)
        for sig in (signal.SIGTERM, signal.SIGINT):
            signal.signal(sig, stop)
        try:
            status = child.wait(timeout=int(os.environ.get("PRIVATE_CHILD_TIMEOUT", "18000")))
        except subprocess.TimeoutExpired:
            stop(signal.SIGTERM, None)
            try:
                child.wait(timeout=30)
            except subprocess.TimeoutExpired:
                stop(signal.SIGKILL, None)
                child.wait()
            output.write(b"\nPrivate child reached its time limit.\n")
            status = 124
    try:
        Store().put(prefix(os.environ["PRIVATE_PROJECT"], os.environ["PRIVATE_BUILD_ID"]) + "/logs/" + log.name, log)
    except Exception:
        with (workdir() / (label + "-transfer.log")).open("w") as f:
            traceback.print_exc(file=f)
        status = 1
    print("Private operation completed." if status == 0 else "Private operation failed; inspect private R2 diagnostics.", flush=True)
    return 0 if status == 0 else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        print("Private operation failed before completion.", file=sys.stderr)
        sys.exit(1)
