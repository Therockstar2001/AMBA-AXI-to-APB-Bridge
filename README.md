### Project: AXI4-Lite to APB Bridge with Verification

## Overview
Designed and verified a synthesizable AXI4-Lite to APB bridge implementing full read/write data paths, protocol-compliant handshake logic, and error propagation. The design supports backpressure via APB wait-states and ensures cycle-accurate transaction translation.

## Design Architecture
* AXI Channels: AW, W, B, AR, R
* APB Interface: PSEL, PENABLE, PWRITE, PREADY, PSLVERR
* FSM-based control for read/write sequencing
* Two-phase APB protocol enforcement (setup + enable)

## Key Features
* AXI VALID/READY handshake compliance
* APB wait-state handling via PREADY
* Error mapping: PSLVERR → AXI BRESP/RRESP
* Back-to-back transaction support
* No data loss under stall conditions

## Verification Environment
* SystemVerilog-based testbench
* Components:
    * Driver
    * Monitor
    * Scoreboard (self-checking)
    * Functional Coverage

## Test Scenarios
* Directed tests (basic read/write)
* Constrained-random tests (stress traffic)
* Error injection (invalid address)
* Backpressure validation (PREADY stalls)

## Regression & Automation
* Automated regression using Makefile
* Batch execution of multiple testcases
* Per-test log generation
* PASS/FAIL detection using log parsing
    * Command:- make all

## Results
* All testcases pass regression
* Coverage ~40% (extendable with additional scenarios)
* No protocol violations observed
* Stable under backpressure and error conditions

## Tools
* SystemVerilog
* QuestaSim
* Linux (Makefile-based automation)

## How to Run
vlib work
vlog *.sv
vsim axi_basic_test

or:

make all

## Future Improvements
* UVM-based environment
* Coverage closure strategy
* Assertion-based verification (SVA)
* Multi-seed regression
