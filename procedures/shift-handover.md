# Shift Handover — Ubuntu Server Operations Lab (Simulated)

**Date:** 25 October 2026 (WIB). **Status:** Last observed verification, not live/continuous monitoring.  
**Environment:** Single Ubuntu VM, local-only test HTTP service; no operational shift transfer actually occurred.

## Last verified state

- `ops-lab-http.service`: healthy in latest recovery screenshot; localhost HTTP request returned `200 OK` and `SERVER-OPS-LAB-OK`.
- Manual service-content monitoring: returned `OK` and exit code `0` after recovery.
- `tmpfs` capacity test: 16 MiB filesystem returned to 0% used after deletion of `capacity-fill.bin`; capacity script `OK`, exit code `0`.
- Software RAID1 (`/dev/md0`) was `[2/2] [UU]` during the initial inventory. No later RAID diagnostic is included in the capacity-test screenshots.

## Completed lab work

- Investigated deliberately invalid `WorkingDirectory` drop-in and observed `status=200/CHDIR`.
- Disabled that drop-in and verified service and HTTP recovery.
- Tested health-check script for inactive service and incorrect HTTP body; restored normal content.
- Tested 80% filesystem usage alert and returned simulated load to baseline.

## Outstanding actions / constraints

1. The operator later confirmed the test `tmpfs` had been unmounted, but no command output or screenshot verified the final mount state. Before any future capacity test, check `findmnt -M` for the exact lab path; do not assume the temporary filesystem still exists.
2. Monitoring is manually invoked, not scheduled or connected to an external alerting system.
3. Capacity-check script's error exit `3` has not been independently tested.
4. Export original Bash files from the VM if exact source-code provenance is required; the GitHub-ready copies were reconstructed from observed scripts.
5. Spreadsheet availability modeling and facility-audit exercises are **out of scope** for this Linux lab and are not claimed as completed.

## Safe checks for next session

```bash
systemctl is-active ops-lab-http.service
~/server-ops-lab/health-check.sh
findmnt -n -M ~/server-ops-lab/capacity-test -o TARGET,FSTYPE
~/server-ops-lab/capacity-check.sh
cat /proc/mdstat
```

Avoid inferring ongoing health from these recorded screenshots alone.
