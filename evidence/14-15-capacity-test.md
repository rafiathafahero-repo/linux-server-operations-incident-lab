# Capacity Threshold Verification — Original Evidence

- [14-capacity-alert.png](14-capacity-alert.png): the lab operator verified `tmpfs`, wrote a 13 MiB file into the 16 MiB test mount, and observed 82% usage. The 80% threshold script returned `CRITICAL` and exit code `2`.
- [15-capacity-recovered.png](15-capacity-recovered.png): the purpose-created test file was removed, `df` reported 0% usage, and the script returned `OK` and exit code `0`.

Original screenshots were submitted on 25 October 2026 (WIB). These two checks demonstrate a **manual, point-in-time** alert and recovery. They do not establish periodic monitoring or production storage availability.
