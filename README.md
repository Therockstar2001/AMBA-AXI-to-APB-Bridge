## AXI4-Lite to APB Bridge Design & Verification

## Project Overview
This project implements and verifies a synthesizable AXI4-Lite to APB bridge that enables protocol-compliant communication between high-performance AXI-based masters and low-bandwidth APB peripherals commonly found in modern System-on-Chip (SoC) architectures. The bridge performs transaction-level protocol translation while preserving functional correctness, timing integrity, and error propagation across two fundamentally different bus protocols.
The implementation focuses not only on RTL functionality but also on establishing a reusable verification environment capable of validating protocol compliance, transaction correctness, corner-case behavior, and interface robustness under realistic operating conditions.
________________________________________
## Design Motivation
Modern SoCs frequently integrate multiple bus protocols optimized for different performance requirements. AXI4-Lite is widely used for processor and high-performance subsystem communication because of its independent channels and pipelined transaction model, whereas APB is optimized for simple peripheral access through a lightweight, non-pipelined protocol.
Direct communication between these protocols is not possible due to differences in transaction sequencing, handshake mechanisms, latency management, and response generation. This bridge resolves these architectural differences by translating AXI transactions into protocol-compliant APB accesses while maintaining data integrity and predictable system behavior.
________________________________________
## Design Objectives
The bridge was designed with the following objectives:
* Protocol-compliant AXI4-Lite read and write transaction handling
* Correct APB two-phase transaction generation
* Reliable synchronization of independent AXI address and data channels
* Robust handling of APB wait-state insertion through PREADY
* Accurate propagation of APB error responses to AXI masters
* Deterministic transaction ordering and completion
* Clean separation between design and verification components
________________________________________
## Architecture
```
┌────────────────────────────────────────────────────────────────────────┐
│                          VERIFICATION TESTBENCH                        │
│                                                                        │
│   ┌───────────────────┐                     ┌──────────────────────┐   │
│   │                   │   AXI Transactions  │                      │   │
│   │  AXI Master / driver  │ ──────────────────────> │                      │   │
│   │                   │                     │                      │   │
│   └───────────────────┘                     │      SCOREBOARD      │   │
│                                             │   (Self-Checking)    │   │
│   ┌───────────────────┐                     │                      │   │
│   │    AXI Monitor    │ ──────────────────────> │                      │   │
│   └─────────┬─────────┘   Observed Activity │                      │   │
└─────────────┼───────────────────────────────┴──────────────────────┘   │
              │                                                          │
              │  (Passive Monitoring)                                    │
              ▼                                                          │
┌────────────────────────────────────────────────────────────────────────┐
│                              BRIDGE DESIGN                             │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                    AXI4-Lite to APB Bridge                     │   │
│   │                                                                │   │
│   │   ┌───────────────────┐               ┌────────────────────┐   │   │
│   │   │ AXI Transaction   │  FSM-Based    │ APB Transaction    │   │   │
│   │   │ Processing Buffer │ ────────────> │ Generation Logic   │   │   │
│   │   └───────────────────┘  Sequencing   └────────────────────┘   │   │
│   └─────────────────────────────────────────────────┬──────────────┘   │
└─────────────────────────────────────────────────────┼──────────────────┘
                                                      │
                                                      │  APB Transfers
                                                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           PERIPHERAL SUBSYSTEM                         │
│                                                                        │
│                     ┌──────────────────────────────────┐               │
│                     │        APB Register Slave        │               │
│                     │  (Memory-Mapped Register Space)   │               │
│                     └──────────────────────────────────┘               │
└────────────────────────────────────────────────────────────────────────┘
```
________________________________________
## AXI Transaction Processing
The bridge supports both AXI4-Lite read and write transactions through the independent AXI channels:
### Write Path:
* Write Address (AW)
* Write Data (W)
* Write Response (B)
Because the AXI address and write data channels are independent, the bridge buffers incoming information until both address and data are available before initiating an APB write transaction.
### Read Path:
* Read Address (AR)
* Read Data (R)
Read requests are translated into APB read operations, with returned APB data forwarded to the AXI master through the AXI read response channel.
________________________________________
## APB Transaction Generation
Each AXI transaction is translated into a protocol-compliant APB transfer consisting of:
Setup Phase
* PSEL asserted
* Address presented
* PENABLE deasserted
Access Phase
* PENABLE asserted
* Control signals held stable
* Transaction completed only after PREADY assertion
The bridge guarantees that APB protocol timing remains compliant throughout wait-state insertion and delayed peripheral responses.
________________________________________
## Internal Transaction Management
A key architectural challenge is the synchronization of AXI’s decoupled address and data channels into APB’s single transaction flow.
To resolve this, the bridge implements:
* Internal address buffering
* Data buffering
* Transaction-valid state tracking
* Deterministic sequencing logic
* FSM-based transaction control
This approach ensures that APB transfers are initiated only after all required AXI information has been captured.
________________________________________
## Wait-State and Backpressure Handling
Peripheral latency is modeled through APB wait-state insertion.
Whenever the APB slave deasserts PREADY:
* APB control signals remain stable
* AXI transaction completion is delayed
* READY signal generation is controlled to prevent protocol violations
* No transaction information is lost
This behavior allows the bridge to correctly propagate peripheral backpressure toward the AXI interface while maintaining transaction ordering.
________________________________________
## Error Handling
The bridge supports protocol-level error propagation between APB and AXI.
When the APB slave reports an error through PSLVERR:
* Write transactions return AXI BRESP = SLVERR
* Read transactions return AXI RRESP = SLVERR
This mechanism preserves software-visible error reporting while maintaining protocol compliance across both interfaces.
________________________________________
## APB Peripheral Model
A register-based APB slave model was developed to emulate realistic peripheral behavior.
The model supports:
* Memory-mapped register accesses
* Configurable register space
* Read and write operations
* Programmable wait-state insertion
* Invalid address detection
* PSLVERR generation
The slave model enables realistic functional verification without relying on external IP.
________________________________________
## Verification Architecture
The project adopts a reusable transaction-level verification architecture composed of independently developed verification components.
### Driver:
Generates protocol-compliant AXI stimulus and drives transactions onto the interface.
### Monitor:
Passively observes bus activity and reconstructs completed transactions without influencing DUT behavior.
### Scoreboard:
Implements self-checking verification by comparing observed DUT behavior against expected transaction results, automatically detecting data mismatches and protocol errors.
### Functional Coverage:
Collects coverage information across transaction types, address usage, and error conditions to measure verification completeness.
________________________________________
## Verification Strategy
Verification was performed using multiple complementary test methodologies.
### Directed Testing:
Deterministic stimulus validating:
* Basic read operations
* Basic write operations
* Register correctness
* Response generation
________________________________________
### Constrained-Random Testing:
Randomized transaction generation was used to exercise:
* Various address locations
* Mixed read/write traffic
* Different transaction ordering
* Corner-case protocol interactions
________________________________________
### Error Injection
Negative testing validates:
* Invalid register accesses
* Error response propagation
* PSLVERR handling
* AXI SLVERR generation
________________________________________
### Wait-State Validation
Artificial APB wait states were introduced to verify:
* Stable control signaling
* Correct transaction completion
* Backpressure propagation
* Latency tolerance
________________________________________
## Self-Checking Verification
All verification is fully self-checking.
Transaction correctness is validated automatically through scoreboard comparisons without requiring manual waveform inspection for functional correctness.
Simulation logs clearly identify:
* Successful transactions
* Data mismatches
* Protocol violations
* Error handling behavior
________________________________________
## Regression Methodology
The verification flow includes automated regression capable of executing multiple verification scenarios in a repeatable manner.
Regression infrastructure provides:
* Automated compilation
* Batch testcase execution
* Individual log generation
* Automatic PASS/FAIL classification
* Consistent verification reporting
This enables rapid verification after RTL modifications while improving reproducibility and debugging efficiency.
________________________________________
## Design Challenges Addressed
The project addresses several common SoC interface challenges, including:
* AXI/APB protocol translation
* Independent AXI channel synchronization
* APB wait-state management
* Transaction ordering
* Protocol-compliant response generation
* Error propagation across protocols
* Backpressure handling
* End-to-end transaction verification
________________________________________
## Verification Results
Verification successfully demonstrated:
* Correct read transaction translation
* Correct write transaction translation
* Stable operation under APB wait states
* Accurate data transfer between interfaces
* Proper protocol error propagation
* Reliable transaction sequencing
* Self-checking verification with functional coverage
* Automated regression execution across multiple verification scenarios
________________________________________
## Formal Verification
* Modern SoC interface IP requires verification beyond simulation to establish protocol correctness under all legal input scenarios. In addition to simulation-based verification, this project employs Assertion-Based Formal Verification using SymbiYosys, Yosys, and the Boolector SMT solver to mathematically prove safety properties of the AXI4-Lite to APB bridge without relying on constrained-random stimulus or directed testcases.
* A dedicated formal environment was developed around the bridge consisting of a top-level formal harness (formal_top.sv), a reusable property library (properties.sv), and SymbiYosys proof scripts. The environment models protocol-compliant AXI and APB behavior through carefully constructed assumptions while allowing the solver to explore all legal transaction sequences within the specified proof bounds.
* Unlike simulation, which validates individual execution scenarios, formal verification exhaustively analyzes all reachable states under the defined assumptions. This complements the simulation environment by proving protocol invariants, transaction correctness, and corner-case behavior that would be difficult or impractical to achieve through stimulus generation alone.
________________________________________
## Formal Verification Methodology
* The formal verification environment was developed incrementally, beginning with basic safety properties and progressively expanding toward complete protocol verification. Properties were organized into logical verification phases covering reset behavior, finite state machine correctness, APB protocol compliance, AXI4-Lite protocol compliance, transaction data integrity, response generation, error propagation, and transaction reachability.
* Additional protocol assumptions were introduced to model compliant AXI master behavior, while bounded fairness constraints were incorporated to represent realistic APB peripheral latency and AXI response acceptance. These assumptions prevent unrealistic solver behavior while maintaining a valid proof environment representative of practical hardware operation.
* The verification flow was executed using SymbiYosys with Boolector as the SMT solver, providing assertion proofs for safety properties together with cover analysis to demonstrate transaction reachability.
________________________________________
## Proven Properties
The formal verification environment establishes mathematical correctness for the following categories of properties:

### Reset and Initialization
* Correct reset initialization of internal bridge state.
* Safe recovery from reset without illegal protocol behavior.

### FSM Correctness
* Legal state transitions only.
* No unreachable or invalid FSM states.
* Deterministic transaction sequencing throughout bridge operation.

### APB Protocol Compliance
* Correct two-phase APB transfer generation.
* Stable address, control, and write data during APB wait states.
* Proper handling of delayed PREADY responses.

### AXI4-Lite Protocol Compliance
* Correct acceptance of independent AXI address and data channels.
* Stable AXI responses while stalled by the master.
* Correct request capture prior to APB transaction generation.
* Proper response persistence until handshake completion.

### Transaction Integrity
* Correct propagation of AXI write address and write data into APB transactions.
* Correct propagation of APB read data back to the AXI read channel.
* Preservation of transaction ordering across protocol translation.

### Error Propagation
* Correct translation of APB PSLVERR into AXI SLVERR responses.
* Verified behavior for both read and write error transactions.

### Bounded Progress
* Verification that accepted transactions complete within the defined bounded execution window under the specified fairness assumptions.
* Prevention of illegal simultaneous outstanding read and write transactions within the bridge architecture.
________________________________________
## Cover Property Verification
In addition to assertion proofs, cover properties were developed to demonstrate that valid transaction scenarios remain reachable under the formal assumptions. Cover analysis confirms successful exploration of representative operating conditions including:
* Successful AXI write transactions.
* Successful AXI read transactions.
* APB error propagation during write operations.
* APB error propagation during read operations.
* Complete end-to-end write transaction execution.
* Complete end-to-end read transaction execution.
Successful cover convergence demonstrates that the assumptions are not over-constraining the design while preserving realistic transaction behavior.
________________________________________
## Formal Verification Environment
The formal environment is organized independently from the simulation testbench to promote reuse and maintainability.
```
formal/
├── axi_bridge.sby
├── axi_bridge_cover.sby
├── formal_top.sv
└── properties.sv
```
* formal_top.sv instantiates the DUT and defines the formal environment.
* properties.sv contains all assumptions, assertions, and cover properties.
* axi_bridge.sby performs assertion-based safety proofs.
* axi_bridge_cover.sby performs reachability analysis using cover properties.
________________________________________
## Future Enhancements
The current implementation establishes a reusable verification platform that can be extended with additional industry-standard verification capabilities, including:
* Universal Verification Methodology (UVM)
* Assertion-Based Verification (SystemVerilog Assertions)
* Coverage closure methodology
* Multi-seed constrained-random regression
* Functional coverage expansion
* Performance and latency monitoring
* Formal protocol verification
* Advanced APB peripheral models
* Support for additional AMBA protocol variants
