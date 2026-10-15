# KANPIM
<img width="2970" height="2145" alt="pykan_pim_motivation" src="https://github.com/user-attachments/assets/e1951f03-8cc9-4452-8235-c3c2fb6fb27c" />
Conducted a roofline experiment. And realized PIM is excellent for Kolmogorov-Arnold Networks.
The timed reports are the final ones.
## Benchmark snapshot

The accelerator evaluates nine piecewise-cubic spline elements in parallel using nine DSP48E1 blocks and nine on-chip coefficient-memory banks.

![Headline throughput](docs/assets/headline_throughput.png)

<p align="center"><sub>CPU and GPU values are measured in Colab with resident data. FPGA performance is a post-synthesis estimate at 99.36 MHz. CPU/GPU use FP32; FPGA uses signed Q8.8.</sub></p>

### Scaling behavior

![Latency scaling](docs/assets/latency_scaling.png)

![Throughput scaling](docs/assets/throughput_scaling.png)

### FPGA resource utilization

![FPGA resource utilization](docs/assets/fpga_resource_utilization.png)

| Metric | Result |
|---|---:|
| FPGA post-synthesis frequency estimate | 99.36 MHz |
| Nine-element FPGA latency estimate | 40.26 ns |
| FPGA steady-state throughput estimate | 178.86 M elements/s |
| Best measured CPU throughput | 45.86 M elements/s |
| Best measured GPU throughput | 238.42 M elements/s |
| FPGA resources | 311 LUTs, 371 registers, 9 DSPs, 9 RAMB36E1 |

> **Status:** The FPGA figures are clock-constrained post-synthesis estimates, not routed or board-measured results. The 100 MHz constraint missed by 0.064 ns. CPU/GPU measurements exclude host-device transfers.
