# SOP — Diagnosing a Local Lab HTTP Service

**Scope:** `ops-lab-http.service` in the isolated Ubuntu VM only. This is a practice SOP, **not** a production change procedure.

## Preflight

1. Confirm host and scope: `hostnamectl`; avoid commands targeting unrelated services or the Ubuntu primary network.
2. Preserve the baseline: note the current service state, expected HTTP response, and recent logs.
3. Do not repeat fault injection if the drop-in file or directory already exists; inspect first.

## Diagnosis (read-only)

```bash
systemctl status ops-lab-http.service --no-pager -l
systemctl cat ops-lab-http.service
sudo journalctl -u ops-lab-http.service -n 25 --no-pager
sudo ss -ltnp '( sport = :8765 )'
curl --max-time 3 -i http://127.0.0.1:8765/health.txt
```

Classify the fault:

- `failed`, `status=200/CHDIR`, `No such file or directory`: inspect `WorkingDirectory` in base unit and drop-ins; confirm directory existence.
- `active (running)` but unexpected body: investigate application response/configuration; HTTP 200 does not prove content correctness.
- `inactive`: first determine whether service was intentionally stopped; check recent logs and relevant operator action.

## Recovery for the controlled CHDIR scenario only

Before any change, confirm `90-fault-injection.conf` is the lab-created override and `.conf.disabled` does not already exist.

```bash
sudo mv /etc/systemd/system/ops-lab-http.service.d/90-fault-injection.conf   /etc/systemd/system/ops-lab-http.service.d/90-fault-injection.conf.disabled
sudo systemctl daemon-reload
sudo systemctl reset-failed ops-lab-http.service
sudo systemctl start ops-lab-http.service
systemctl status ops-lab-http.service --no-pager -l
curl --max-time 3 -i http://127.0.0.1:8765/health.txt
sudo ss -ltnp '( sport = :8765 )'
```

**Do not run the rename command** if the fault override was already disabled or if the source file is absent. The operator's recovery was already performed in this lab.

## Verification / closure

- Confirm `active (running)` and actual TCP listener.
- Confirm `HTTP 200` and `SERVER-OPS-LAB-OK` from the local endpoint.
- Run `~/server-ops-lab/health-check.sh`; record `OK` and exit `0`.
- Report what caused the failure, what changed, what was tested, and what remains unknown.
- Leave the test service unmodified after verification.

## Escalation trigger

For a real environment, if the fault cannot be isolated with read-only checks, **stop unapproved changes** and escalate using the organization's documented support and change-control process. None was executed in this simulated exercise.
