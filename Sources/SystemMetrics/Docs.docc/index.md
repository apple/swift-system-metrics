# ``SystemMetrics``

Collect and report process-level system metrics in your application.

## Overview

Create an instance of ``SystemMetricsMonitor`` to automatically collect key process metrics and report them through the Swift Metrics API.

The monitor collects the following metrics:

- **Virtual Memory**: Total virtual memory, in bytes, that the process allocates. The monitor reports the metric as `process_virtual_memory_bytes`.
- **Resident Memory**: Physical memory, in bytes, that the process currently uses. The monitor reports the metric as `process_resident_memory_bytes`.
- **Start Time**: Process start time, in seconds, since UNIX epoch. The monitor reports the metric as `process_start_time_seconds`.
- **CPU Time**: Cumulative CPU time the process consumes, in seconds. The monitor reports the metric as `process_cpu_seconds_total`.
- **Max File Descriptors**: The maximum number of file descriptors the process can open. The monitor reports the metric as `process_max_fds`.
- **Open File Descriptors**: The number of file descriptors the process currently has open. The monitor reports the metric as `process_open_fds`.

> Note: The monitor supports these metrics only on Linux and macOS platforms.

## Topics

### Monitor system metrics

- <doc:GettingStarted>
- ``SystemMetricsMonitor``

### Contribute to the project

- <doc:Proposals>
