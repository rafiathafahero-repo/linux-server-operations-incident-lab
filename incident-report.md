# Incident Report — Controlled Linux Service and Capacity Faults

**Exercise ID:** OPS-LAB-2026-10-25  
**System:** `ubuntu-bootcamp` (Ubuntu 26.04 LTS / VirtualBox)  
**Date:** 25 October 2026 (WIB)  
**Classification:** Planned fault injection in a personal virtual lab; **not a production incident**  
**Final observed state:** HTTP service restored and responsive; capacity-test file removed; monitoring outputs healthy. **The operator later reported unmounting the `tmpfs`; no terminal verification was submitted for that action.**

## Executive summary

This exercise investigated three deliberately created failure states: (A) HTTP service startup failure due to an invalid systemd `WorkingDirectory`, (B) unhealthy service/content conditions detected by a Bash check, and (C) a capacity threshold crossed in an isolated 16 MiB `tmpfs`. For each, the operator obtained a baseline, performed a controlled change, recorded a diagnostic observation, and demonstrated recovery. Source screenshots are indexed in [`evidence/README.md`](evidence/README.md).

## A — HTTP service startup failure (`200/CHDIR`)

| Field | Observation |
|---|---|
| Baseline | `ops-lab-http.service` active; Python HTTP `200 OK`, `SERVER-OPS-LAB-OK`, listener on `127.0.0.1:8765` |
| Controlled change | Created `90-fault-injection.conf` that set `WorkingDirectory=/home/rafi/server-ops-lab/invalid-working-directory` |
| Symptom | `systemctl` showed failed, `status=200/CHDIR`; `curl` failed to connect |
| Root-cause evidence | `systemctl cat` displayed the overriding path; `journalctl` showed `Failed at step CHDIR` and `No such file or directory`; `test -d` showed the path missing |
| Corrective action | Renamed the lab drop-in to `.conf.disabled`, reloaded systemd, reset failed state, and started only the lab unit |
| Recovery validation | `active (running)`, HTTP `200 OK`, correct text body, and Python listener visible in `ss` |

**Root cause:** systemd could not change into the nonexistent working directory when starting the lab process. The fault was a configuration-path error, not evidence of a failing disk, network path or Python installation.

**Primary evidence:** [baseline status](evidence/03b-systemd-service-active.png), [fault](evidence/04c-service-failure.png), [unit override](evidence/05a-service-override.png), [logs](evidence/05b-journalctl-chdir-error.png), [service recovery](evidence/06c-service-active.png), [HTTP recovery](evidence/06d-http-recovered.png).

## B — Manual health-monitor failure detection

The operator used a Bash health check that performed three sequential tests: systemd service activity, HTTP request success, and the exact expected HTTP response body.

| Condition | Observed status | Script result |
|---|---|---|
| Healthy | Service active, expected text | `OK`, exit `0` |
| Intentionally stopped | Service inactive | `CRITICAL: Service is not active`, exit `2` |
| Service restarted | Service active, expected text | `OK`, exit `0` |
| Content deliberately corrupted | Service **active**, HTTP **200**, unexpected text | `CRITICAL: Unexpected HTTP response`, exit `2` |
| Content restored | Service active, expected text | `OK`, exit `0` |

**Interpretation:** A process can be active without returning an acceptable application response. HTTP `200 OK` alone did not meet the scripted health contract.

**Recovery caveat:** The operator mistyped the initial backup command (`Scp` rather than `cp`), so no `.bak` file was created. A later `mv` from that missing backup failed. The operator then restored `health.txt` by writing the known-good `SERVER-OPS-LAB-OK` content and repeated the check successfully. The failed intermediate commands are retained in screenshots instead of being edited out.

**Primary evidence:** [normal check](evidence/07c-health-check-baseline.png), [inactive service](evidence/08a-service-stopped.png), [critical detection](evidence/08b-monitoring-critical.png), [restart/recovery](evidence/09a-monitoring-recovered.png), [bad-body detection](evidence/10c-invalid-http-response-detected.png), [corrected body](evidence/11b-http-health-check-reverified.png).

## C — Capacity threshold and cleanup

| Stage | Observation |
|---|---|
| Baseline | Exact `tmpfs` mount at `/home/rafi/server-ops-lab/capacity-test`, 16 MiB capacity and 0% usage |
| Policy | Local script reports `CRITICAL` when usage is **at least 80%** |
| Fault | Created **13 MiB** `capacity-fill.bin` inside the verified mount; `df -hT` showed **82%** usage |
| Detection | `CRITICAL: Filesystem usage 82% (threshold 80%)`, exit `2` |
| Recovery | Deleted only `capacity-fill.bin`; usage returned to 0%; same script reported `OK`, exit `0` |

**Safety boundary:** Only a small memory-backed filesystem was used. The test did not fill the Ubuntu root filesystem or RAID1. No physical disk-failure scenario was conducted during this project.

**Primary evidence:** [tmpfs baseline](evidence/12-capacity-tmpfs-baseline.png), [monitoring baseline](evidence/13b-capacity-monitoring-baseline.png), [alert at 82%](evidence/14-capacity-alert.png), [restored at 0%](evidence/15-capacity-recovered.png).

## Event sequence (not a complete timestamped audit log)

1. System resources and RAID status inspected; required tools checked.
2. Scoped Python HTTP service created, started, and baseline validated.
3. Invalid systemd directory override applied; startup failed.
4. Override, journal and missing directory inspected; cause isolated.
5. Override disabled; service and HTTP endpoint independently verified healthy.
6. Manual Bash health check exercised against healthy, inactive and invalid-response scenarios; verified recovered results.
7. Isolated 16 MiB `tmpfs` and Bash capacity checker created.
8. Test write raised usage to 82%, causing alert; removal returned usage to 0% and check to OK.

Times were read only where visible in screenshots; this ordered sequence **does not represent a production change ticket or a continuously monitored time series**.

## Lessons and follow-up

- Read both the service unit and logs before restarting repeatedly. `200/CHDIR` identifies a stage of systemd's startup procedure.
- Verify process state, socket binding, HTTP result **and content** as separate questions.
- Validate the exact filesystem mount before controlled capacity writes; no unverified root or RAID filesystems were touched.
- Maintain a reversible lab-only change, record failures and operator errors, and retest independently after correction.
- **Housekeeping:** The operator subsequently reported unmounting the empty `tmpfs`. No screenshot or machine output of that step was submitted; this remains user-reported rather than independently verified.
- Health scripts were manually executed, not deployed as timers or alerting agents. The capacity script's exit `3` error branch has not been tested in the supplied evidence.

## Evidence provenance

All screenshots were supplied by the operator from the Ubuntu VM. Documentation and script copies were assembled from the displayed commands and observations; they are not verified byte-for-byte exports of original VM files. No claim of production impact, physical replacement, external escalation, or measured uptime is made.
