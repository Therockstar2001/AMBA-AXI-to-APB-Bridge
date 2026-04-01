### Project: AXI4-Lite to APB Bridge

## Overview
This project implements a synthesizable bridge converting AXI4-Lite transactions into APB protocol transactions. 
The design handles both read and write paths, supports wait-state insertion, and propagates error conditions from APB to AXI.

## Architecture

# AXI Side

Channels:
-> Write Address (AW)
-> Write Data (W)
-> Write Response (B)
-> Read Address (AR)
-> Read Data (R)

Handshake:
-> VALID/READY based flow control

# APB Side

Signals:
-> PSEL (select)
-> PENABLE (phase control)
-> PWRITE (direction)
-> PADDR, PWDATA, PRDATA
-> PREADY (wait-state control)
-> PSLVERR (error signal)

## Transaction Flow

# Write Transaction
AXI accepts AWADDR via AWVALID/AWREADY
AXI accepts WDATA via WVALID/WREADY
Bridge initiates APB setup phase:
    -> PSEL = 1, PENABLE = 0
APB enable phase:
    -> PENABLE = 1
Wait for PREADY
Generate AXI response:
    -> BVALID = 1
    -> BRESP = OKAY / SLVERR

# Read Transaction
AXI accepts ARADDR via ARVALID/ARREADY
APB setup + enable phase
PRDATA captured
AXI response:
    -> RVALID = 1
    -> RDATA = PRDATA
    -> RRESP = OKAY / SLVERR

## Wait-State Handling
APB slave can delay transfer using PREADY = 0
Bridge holds transaction in enable phase until PREADY = 1
AXI response is delayed accordingly
Ensures protocol-safe backpressure propagation

## Error Handling
Invalid address region triggers:
    -> PSLVERR = 1
Bridge maps:
    -> PSLVERR → BRESP = 2 (SLVERR)
    -> PSLVERR → RRESP = 2 (SLVERR)

## Verification Strategy

# Environment
Simulator: QuestaSim
Testbench: SystemVerilog

# Scenarios Covered
Valid write transactions
Valid read transactions
Back-to-back traffic (stress behavior)
Wait-state insertion via configurable delay
Error injection (invalid address access)

# Observations
AXI to APB mapping is cycle-accurate
APB two-phase protocol strictly followed
Wait-state propagation verified (PREADY stalls)
Error propagation verified across both read/write paths

## Waveform Insights
Due to dense traffic generation, waveforms show continuous transactions.
Key behaviors validated include:

Proper handshake synchronization
Correct APB phase transitions
Accurate response timing
No protocol violations under backpressure

## Design Decisions
Chose AXI4-Lite for simplicity (no burst handling)
Implemented FSM-based bridge control
Explicit separation of read/write paths
Configurable wait-state generation for realism

## Key Takeaways
Deep understanding of AXI and APB protocols
Experience with handshake-driven designs
Exposure to real hardware behavior (latency, stalls, errors)
Practical verification using waveform-based debugging

## Tools & Technologies
SystemVerilog
QuestaSim
Digital Design (RTL)
Bus Protocols: AXI4-Lite, APB

## Future Improvements (optional)
Add UVM-based verification environment
Functional coverage collection
Formal protocol checking (SVA)
Burst support (AXI full)
