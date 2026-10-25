# Original Terminal Evidence — Index and Provenance

**Scope:** Controlled Linux service and capacity lab inside an Ubuntu VM, 25 October 2026 (WIB). All screenshots are original captures supplied by the lab operator. They are not generated or re-created terminal screenshots. Outputs document point-in-time conditions; the documentation explains where source files and historical logs were not directly exported.

**Collection size:** 34 PNG files. See [`SHA256SUMS.txt`](SHA256SUMS.txt) for their SHA-256 digests.

| Screenshot | Verified observations |
|---|---|
| [01a-system-cpu-memory.png](01a-system-cpu-memory.png) | `hostnamectl`: Ubuntu 26.04 LTS, `ubuntu-bootcamp`, Oracle VirtualBox. `lscpu`: two logical CPUs, x86_64. `free -h`: 5.3 GiB memory total and 4.1 GiB estimated available at capture. |
| [01b-storage-filesystem.png](01b-storage-filesystem.png) | `lsblk`: 30 GB OS disk `sda`, extra mdadm RAID member disks; `df -hT`: root ext4 filesystem 30 GB with 65% use at capture. `/dev/md0` is visible but not shown mounted. |
| [02-environment-readiness.png](02-environment-readiness.png) | `python3`, `curl`, `systemctl`, `journalctl`, and `ss` are present. `/proc/mdstat`: RAID1 `/dev/md0` active with two active members, `[2/2] [UU]`, `sdd[2]` and `sdc[1]`. |

**Limits:** These are point-in-time checks of one local VM. An active RAID status does not verify a mounted filesystem, every file's integrity, full hardware health, or production availability.

## Phase 02 — Local HTTP service baseline (observed)

| Screenshot | Verified observations |
|---|---|
| [03a-preflight-and-health-file.png](03a-preflight-and-health-file.png) | Lab directory and unit filename were available, no listener listed on port 8765; disposable health file contained `SERVER-OPS-LAB-OK`. |
| [03b-systemd-service-active.png](03b-systemd-service-active.png) | `ops-lab-http.service` started successfully as Python `http.server`; `systemctl status` showed `active (running)` and `disabled` (not enabled at boot). |
| [03c-http-and-port-check.png](03c-http-and-port-check.png) | `curl` returned HTTP/1.0 `200 OK` with `SERVER-OPS-LAB-OK`; `ss` showed Python listening on `127.0.0.1:8765`. |

**Limits:** HTTP `200 OK` confirms the local endpoint worked at the instant of testing; this does not prove persistent service availability or production use. The three screenshots were supplied directly by the lab operator. The service subsequently underwent controlled fault injection; see Phase 03 evidence below.

## Phase 03 — Controlled service failure (observed)

| Screenshot | Verified observations |
|---|---|
| [04a-fault-preflight.png](04a-fault-preflight.png) | Deliberate invalid working directory was absent; `90-fault-injection.conf` name was available. |
| [04b-systemd-fault-override.png](04b-systemd-fault-override.png) | A drop-in file set `WorkingDirectory=/home/rafi/server-ops-lab/invalid-working-directory` for the lab-only service. |
| [04c-service-failure.png](04c-service-failure.png) | After reload/restart, `ops-lab-http.service` was `failed` with `status=200/CHDIR`; systemd reported `No such file or directory` for working-directory change, and curl could not connect to port 8765. |

**Evidence interpretation:** The deliberately absent directory explains the service startup failure. See Phase 04B for subsequently observed recovery.

## Phase 04A — Root cause verification (observed)

| Screenshot | Verified observations |
|---|---|
| [05a-service-override.png](05a-service-override.png) | `systemctl cat` shows the unit working directory `/home/rafi/server-ops-lab` being overridden by `/home/rafi/server-ops-lab/invalid-working-directory`. |
| [05b-journalctl-chdir-error.png](05b-journalctl-chdir-error.png) | Journal shows `Failed at step CHDIR` and `status=200/CHDIR` with `No such file or directory`; it also retains the earlier successful HTTP request and subsequent failed start. |
| [05c-directory-missing.png](05c-directory-missing.png) | `test -d` confirms the deliberately invalid working directory does not exist. |

**Verified root cause:** The controlled drop-in override referenced a nonexistent working directory, preventing systemd from starting the Python HTTP service. Recovery was subsequently demonstrated in Phase 04B evidence.

## Phase 04B — Recovery and functional verification (observed)

| Screenshot | Verified observations |
|---|---|
| [06a-override-disabled.png](06a-override-disabled.png) | Backup name available; the fault override renamed to a `.conf.disabled` file, so systemd will not load it as a normal `.conf` drop-in. |
| [06b-systemd-recovery-commands.png](06b-systemd-recovery-commands.png) | `daemon-reload`, `reset-failed` and `start` issued for the lab-only service without an error shown. |
| [06c-service-active.png](06c-service-active.png) | `systemctl status` shows `ops-lab-http.service` as `active (running)` using Python HTTP server, PID 6019. |
| [06d-http-recovered.png](06d-http-recovered.png) | `curl` returns HTTP/1.0 `200 OK` and `SERVER-OPS-LAB-OK` from `127.0.0.1:8765/health.txt`. |
| [06e-port-listening.png](06e-port-listening.png) | `ss -ltnp` confirms Python PID 6019 listening on `127.0.0.1:8765`. |

**Verified recovery:** A disabled override and a successful service restart were followed by both a healthy HTTP response and an active local TCP listener. These are point-in-time observations, not long-term uptime or production-service evidence.

## Phase 05A — Bash health-check baseline (observed)

| Screenshot | Verified observations |
|---|---|
| [07a-script-name-available.png](07a-script-name-available.png) | Shell check confirms `~/server-ops-lab/health-check.sh` did not exist before creation. |
| [07b-health-check-script-created.png](07b-health-check-script-created.png) | Terminal shows the Bash script creation, including systemd service-status check, local HTTP request and exact expected response, with success/failure exit codes. This is a capture of the creation command, not an independent byte-for-byte export of the script file. |
| [07c-health-check-baseline.png](07c-health-check-baseline.png) | `bash -n` returns `Syntax OK`; executing the script produces `OK: Service and HTTP endpoint healthy` and `Exit code: 0` (timestamp shown in the screenshot). |

**Limits:** This is an on-demand script, not yet a scheduled or continuously running monitor. No external alert delivery or production monitoring is claimed.

## Phase 05B — Health-check fault detection and recovery (observed)

| Screenshot | Verified observations |
|---|---|
| [08a-service-stopped.png](08a-service-stopped.png) | Lab-only `ops-lab-http.service` intentionally stopped; `systemctl is-active` reports `inactive`. |
| [08b-monitoring-critical.png](08b-monitoring-critical.png) | Running the existing Bash monitor while inactive produced `CRITICAL: Service is not active` and `Exit code: 2`. |
| [09a-monitoring-recovered.png](09a-monitoring-recovered.png) | `systemctl start` followed by the same script produced `OK: Service and HTTP endpoint healthy` and `Exit code: 0`. |
| [09b-http-endpoint-recovered.png](09b-http-endpoint-recovered.png) | Independent curl verification returned HTTP/1.0 `200 OK` and expected `SERVER-OPS-LAB-OK` body. |

**Result:** The same health-check script distinguished inactive service (critical/exit 2) from a restored healthy service (OK/exit 0). These are manually invoked checks; periodic scheduling and external alert delivery have not yet been demonstrated.

## Phase 05C — HTTP-content mismatch detection and recovery (observed)

| Screenshot | Verified observations |
|---|---|
| [10a-http-fault-preflight.png](10a-http-fault-preflight.png) | Service reported `active`; the original health file contained `SERVER-OPS-LAB-OK`; name `health.txt.bak` was available. |
| [10b-backup-command-error-and-fault-injection.png](10b-backup-command-error-and-fault-injection.png) | The attempted backup used an incorrect command (`Scp` with uppercase S), resulting in `Command not found`; `printf` then replaced the test endpoint body with `SERVER-OPS-LAB-UNHEALTHY`. No successful backup creation is evidenced. |
| [10c-invalid-http-response-detected.png](10c-invalid-http-response-detected.png) | Service still reported `active` and HTTP returned `200 OK`, but body was `SERVER-OPS-LAB-UNHEALTHY`; Bash health check reported `CRITICAL: Unexpected HTTP response`, with `Exit code: 2`. |

**Result:** The on-demand health check correctly detected application-content mismatch even when the process was running and HTTP status was 200. The operator first attempted restoring a missing `.bak` file (which failed) and subsequently restored the known-good endpoint body directly with `printf`. The two verification screenshots below confirm restored health; no successful `.bak` restoration is claimed.

| Screenshot | Verified observations |
|---|---|
| [11a-http-response-restored.png](11a-http-response-restored.png) | `printf` writes expected `SERVER-OPS-LAB-OK`; `cat` confirms; script reports healthy (`exit 0`); independent curl returns HTTP `200 OK` with expected body. |
| [11b-http-health-check-reverified.png](11b-http-health-check-reverified.png) | Repeated recovery verification on the live test service: expected response, monitoring OK, exit code 0, HTTP 200 OK, and correct body. |

**Note:** The failed backup and restore commands remain part of the documented learning sequence. These are point-in-time observations, not evidence of continuous monitoring.

**Evidence integrity:** All screenshots are source terminal captures. Any AI-generated infographic must not be treated as evidence of terminal output.

## Phase 06A — Isolated capacity test filesystem (observed)

| Screenshot | Verified observations |
|---|---|
| [12-capacity-tmpfs-baseline.png](12-capacity-tmpfs-baseline.png) | `findmnt -T` confirms `tmpfs` mounted at `/home/rafi/server-ops-lab/capacity-test` with `size=16384k`, `mode=700`, `uid=1000`, `gid=1000`; `df -hT` shows 16M size, 0 used, 16M available and 0% utilization at the time of capture. |

**Limitations:** This is a volatile memory-backed, bounded test filesystem, not a production disk or RAID capacity measurement. Threshold alerting had not yet been tested at this baseline checkpoint; see Phase 06C below.


## Phase 06B — Capacity-monitoring baseline (observed)

| Screenshot | Verified observations |
|---|---|
| [13a-capacity-monitoring-script.png](13a-capacity-monitoring-script.png) | Original terminal screenshot of the Bash script creation: validates `tmpfs` mount, reads filesystem percentage using `df`, reports `OK` under 80% or `CRITICAL` at/above 80%, and uses exit 0/2 (3 on detection errors). |
| [13b-capacity-monitoring-baseline.png](13b-capacity-monitoring-baseline.png) | `bash -n` reports `Syntax OK`; executable capacity check reports `OK: Filesystem usage 0% (threshold 80%)` and `Exit code: 0`. |

**Limitations:** This section documents the baseline (OK path) at that checkpoint. The later high-capacity alert and recovery are documented in Phase 06C. The screenshots show on-demand checks, not periodic automated monitoring or notifications.

## Phase 06C — Controlled high-capacity alert and recovery (observed)

| Screenshot | Verified observations |
|---|---|
| [14-capacity-alert.png](14-capacity-alert.png) | Exact `tmpfs` mount verified; test filename available; `dd` wrote 13 MiB into the 16 MiB temporary filesystem. `df -hT` showed 13M used, 3.0M available and 82% use; the capacity monitoring script displayed `CRITICAL: Filesystem usage 82% (threshold 80%)`, `Exit code: 2`. |
| [15-capacity-recovered.png](15-capacity-recovered.png) | `capacity-fill.bin` was removed; `df -hT` showed 0M used / 0% use; the same script displayed `OK: Filesystem usage 0% (threshold 80%)`, `Exit code: 0`. |

**Limitations:** Only a bounded local `tmpfs` was filled. This test does not show a full OS disk, a full RAID array, periodic monitoring, or external alert delivery. The operator subsequently stated the `tmpfs` was unmounted, but no supporting terminal screenshot was submitted.
