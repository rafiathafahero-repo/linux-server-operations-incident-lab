# Command Reference — Linux Server Operations Lab

These steps describe the **observed procedure** in a form that is easy to review or reproduce. They are **not an exported shell history**, and the files in `monitoring/` and `service/` were reconstructed from the visible terminal session.

> **Safety:** All write operations below are for a disposable Ubuntu VM and the deliberately named test service. **Do not run this as one copy-paste script.** Stop if a preflight check differs from the expected result; verify paths, privileges and scope before creating/moving a file or changing a service. The original lab has already run, so rerunning setup on the same VM can produce conflicts.

## 1. System inventory (read-only)

```bash
hostnamectl
lscpu | grep -E 'Architecture|CPU\(s\)|Model name'
free -h
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
df -hT
for tool in python3 curl systemctl journalctl ss; do
  command -v "$tool" || echo "$tool NOT FOUND"
done
cat /proc/mdstat
```

**Recorded observation:** Ubuntu 26.04 LTS on VirtualBox; 2 virtual CPUs; RAM total 5.3 GiB, 4.1 GiB available; 30 GiB OS disk; RAID1 `[2/2] [UU]` at the initial baseline. These values are specific to this VM and capture.

## 2. Local HTTP service deployment

Perform the two **preflight checks** first and stop if either reports `STOP`:

```bash
test ! -e "$HOME/server-ops-lab" && echo 'Lab directory available' || echo 'STOP: directory exists'
test ! -e /etc/systemd/system/ops-lab-http.service && echo 'Unit name available' || echo 'STOP: unit exists'
sudo ss -H -ltn '( sport = :8765 )'  # Expected: no listener
```

The lab operator then created the directory and expected response file:

```bash
mkdir -p "$HOME/server-ops-lab/www"
printf 'SERVER-OPS-LAB-OK\n' > "$HOME/server-ops-lab/www/health.txt"
cat "$HOME/server-ops-lab/www/health.txt"
```

The corresponding unit definition is in [`service/ops-lab-http.service`](service/ops-lab-http.service). In the VM it was installed at `/etc/systemd/system/ops-lab-http.service`, using `User=rafi`, a fixed lab directory and `ExecStart` for `/usr/bin/python3 -u -m http.server 8765 --bind 127.0.0.1 ...`.

```bash
# Only after validating the unit has the intended contents:
sudo systemctl daemon-reload
sudo systemctl start ops-lab-http.service
systemctl status ops-lab-http.service --no-pager -l
curl -i http://127.0.0.1:8765/health.txt
sudo ss -ltnp '( sport = :8765 )'
```

At baseline, `systemctl` showed **active (running)** but **disabled** (not enabled for boot). A TCP listener was visible on loopback and curl returned HTTP `200 OK` and the expected text.

## 3. Controlled `WorkingDirectory` fault

For reference only; **do not repeat** unless deliberately starting a new disposable lab. Verify the target drop-in does not exist and the invalid directory is absent:

```bash
test ! -e "$HOME/server-ops-lab/invalid-working-directory" && echo absent || echo STOP
sudo test ! -e /etc/systemd/system/ops-lab-http.service.d/90-fault-injection.conf && echo available || echo STOP
```

The observed drop-in contained:

```ini
[Service]
WorkingDirectory=/home/rafi/server-ops-lab/invalid-working-directory
```

It was placed at `/etc/systemd/system/ops-lab-http.service.d/90-fault-injection.conf` and then tested:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ops-lab-http.service
systemctl status ops-lab-http.service --no-pager -l
curl --max-time 3 -i http://127.0.0.1:8765/health.txt
```

The restart was expected to fail. `systemctl` reported `status=200/CHDIR`, and curl failed to connect.

## 4. Diagnose using logs and configuration

```bash
systemctl cat ops-lab-http.service
sudo journalctl -u ops-lab-http.service -n 25 --no-pager
test -d /home/rafi/server-ops-lab/invalid-working-directory && echo 'Directory exists' || echo 'Directory missing'
```

The override pointed at the non-existent directory. The journal showed `Failed at step CHDIR` and `No such file or directory`.

## 5. Restore the service and independently verify

**Only when the original `.conf` fault file exists and `.conf.disabled` does not already exist:**

```bash
sudo mv /etc/systemd/system/ops-lab-http.service.d/90-fault-injection.conf \
  /etc/systemd/system/ops-lab-http.service.d/90-fault-injection.conf.disabled
sudo systemctl daemon-reload
sudo systemctl reset-failed ops-lab-http.service
sudo systemctl start ops-lab-http.service
systemctl status ops-lab-http.service --no-pager -l
curl --max-time 3 -i http://127.0.0.1:8765/health.txt
sudo ss -ltnp '( sport = :8765 )'
```

This restoration was completed successfully in the observed session. Do **not** repeat the rename now that the override is disabled.

## 6. Health monitoring: three scenarios

The source for the reconstructed script appears at [`monitoring/health-check.sh`](monitoring/health-check.sh). Original script creation and observed console checks are in the [evidence index](evidence/README.md).

```bash
bash -n "$HOME/server-ops-lab/health-check.sh"
"$HOME/server-ops-lab/health-check.sh"
echo "Exit code: $?"
```

**Observed success:** exact HTTP body `SERVER-OPS-LAB-OK`, exit `0`.

**Intentional stopped-service test:**

```bash
sudo systemctl stop ops-lab-http.service
systemctl is-active ops-lab-http.service
"$HOME/server-ops-lab/health-check.sh"
echo "Exit code: $?"  # Observed: 2
sudo systemctl start ops-lab-http.service
"$HOME/server-ops-lab/health-check.sh"
echo "Exit code: $?"  # Observed: 0
```

**Intentional content-mismatch test:** The test `health.txt` was changed to `SERVER-OPS-LAB-UNHEALTHY`. The service remained active and curl returned HTTP `200`, but the script correctly exited `2` because the body was not the expected text.

A backup command was mistyped (`Scp`, which failed); the initial `mv` restore also failed because `.bak` did not exist. Actual successful recovery used:

```bash
printf 'SERVER-OPS-LAB-OK\n' > "$HOME/server-ops-lab/www/health.txt"
"$HOME/server-ops-lab/health-check.sh"
echo "Exit code: $?"  # Observed: 0
curl -i http://127.0.0.1:8765/health.txt
```

## 7. Controlled capacity test (memory-backed filesystem)

The observed lab first checked a unique directory name and mounted a small `tmpfs`:

```bash
test ! -e "$HOME/server-ops-lab/capacity-test" && echo available || echo STOP
mkdir -p "$HOME/server-ops-lab/capacity-test"
sudo mount -t tmpfs -o "size=16m,mode=0700,uid=$(id -u),gid=$(id -g)" \
  tmpfs "$HOME/server-ops-lab/capacity-test"
findmnt -n -M "$HOME/server-ops-lab/capacity-test" -o TARGET,FSTYPE
df -hT "$HOME/server-ops-lab/capacity-test"
```

**Do not proceed unless the exact mount is identified as `tmpfs`.** The checker source is in [`monitoring/capacity-check.sh`](monitoring/capacity-check.sh).

```bash
bash -n "$HOME/server-ops-lab/capacity-check.sh"
"$HOME/server-ops-lab/capacity-check.sh"
echo "Exit code: $?"  # Observed: OK, 0%, code 0
```

After confirming the target and that the filename was absent, the operator created **13 MiB only within the 16 MiB tmpfs**:

```bash
test ! -e "$HOME/server-ops-lab/capacity-test/capacity-fill.bin" && echo available || echo STOP
dd if=/dev/zero of="$HOME/server-ops-lab/capacity-test/capacity-fill.bin" \
  bs=1M count=13 conv=excl status=progress
df -hT "$HOME/server-ops-lab/capacity-test"
"$HOME/server-ops-lab/capacity-check.sh"
echo "Exit code: $?"  # Observed: 82%, CRITICAL, code 2
```

The test file was then removed, and the same checks showed **0% used**, `OK`, exit `0`:

```bash
rm -- "$HOME/server-ops-lab/capacity-test/capacity-fill.bin"
df -hT "$HOME/server-ops-lab/capacity-test"
"$HOME/server-ops-lab/capacity-check.sh"
echo "Exit code: $?"
```

## 8. Optional cleanup — **user-reported as completed; no terminal evidence submitted**

The high-capacity file was removed and its recovery verified in screenshots. The operator later confirmed that the test `tmpfs` was also unmounted. Because no `umount` output or post-unmount mount check was submitted, this is **reported housekeeping, not a screenshot-verified result**. The following commands record the safe procedure for reuse only after confirming the target is still mounted:

```bash
TARGET="$HOME/server-ops-lab/capacity-test"
findmnt -n -M "$TARGET" -o TARGET,FSTYPE
ls -A "$TARGET"
```

Only if the target is exactly the lab directory, `FSTYPE` is `tmpfs`, and the listing is empty:

```bash
sudo umount "$HOME/server-ops-lab/capacity-test"
# Optional negative test; not observed in submitted screenshots:
"$HOME/server-ops-lab/capacity-check.sh"
echo "Exit code: $?"   # Intended: ERROR and 3
```

The `umount` is **reported by the operator as performed, not independently evidenced**; the missing-mount exit-code test (`3`) is an **example, not a demonstrated result**. Do not remove or unmount `/`, `/dev/md0`, any system location, or another existing filesystem. The local HTTP service does not need to be stopped to complete this capacity test.
