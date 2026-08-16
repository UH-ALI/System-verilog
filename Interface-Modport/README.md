# APB Slave Verification Using SystemVerilog

## Overview

This lab implements a simple APB-like master/slave verification environment using SystemVerilog.

The design uses three main transaction signals:

- `add` — 32-bit address
- `data` — 32-bit data
- `writing` — read/write control

A `read_data` signal is used for read operations.

The testbench generates randomized transactions, sends them to the driver through a mailbox, drives the DUT through a virtual interface, monitors the DUT signals, and checks the results using a scoreboard.

The address remains **32 bits**, but is constrained to **0–255** for this lab so that randomized addresses stay within the implemented memory range.

## File Structure

```text
design.sv
testbench.sv
README.md
```

### `design.sv`

Contains the hardware side:

- `apb_if` interface
- `DRIVER`, `DUT`, and `MONITOR` modports
- `slave` DUT
- 256-location × 32-bit memory

### `testbench.sv`

Contains the verification environment:

- `transaction`
- `generator`
- `driver`
- `monitor`
- `scoreboard`
- `tb`

## Verification Flow

```text
Generator
    |
    | transaction
    v
Mailbox (gen2drv)
    |
    v
Driver
    |
    | Virtual Interface
    v
DUT / Slave
    |
    | Interface signals
    v
Monitor
    |
    | transaction
    v
Mailbox (mon2sb)
    |
    v
Scoreboard
    |
    v
Expected vs Actual
    |
    +----> PASS / FAIL
```

## Main Components

### 1. Transaction

The `transaction` class represents one read/write operation.

It contains:

```systemverilog
rand bit [31:0] add;
rand bit [31:0] data;
rand bit        writing;
```

The address is constrained:

```systemverilog
constraint address_c {
    add inside {[0:255]};
}
```

Therefore:

- Address → randomized, but limited to 0–255
- Data → randomized 32-bit value
- Writing → randomized 0/1

### 2. Generator

The generator creates and randomizes transaction objects using `randomize()`.

It sends each transaction to the driver through the `gen2drv` mailbox.

```text
Generator → Mailbox → Driver
```

### 3. Mailbox

Mailboxes provide communication between independent testbench components.

Two mailboxes are used:

- `gen2drv` — Generator → Driver
- `mon2sb` — Monitor → Scoreboard

### 4. Driver

The driver receives a transaction from the generator and converts the transaction-level information into DUT signals.

It uses a **virtual interface** to drive:

```text
add
data
writing
```

This provides the connection between the class-based testbench and the hardware interface.

### 5. Interface and Modports

The interface provides the communication signals between the testbench and DUT.

The modports define the direction and intended use of those signals:

- `DRIVER` — drives signals toward the DUT
- `DUT` — receives inputs and produces `read_data`
- `MONITOR` — observes the interface

### 6. DUT / Slave

The slave contains:

```systemverilog
logic [31:0] mem [0:255];
```

For a write:

```text
writing = 1
    |
    +--> mem[address] = data
```

For a read:

```text
writing = 0
    |
    +--> read_data = mem[address]
```

This demonstrates basic master-to-slave write and slave-to-master read behavior.

### 7. Monitor

The monitor observes the DUT through the virtual interface.

For a write, it captures the input `data`.

For a read, it captures the DUT's `read_data`.

It then creates a transaction and sends it to the scoreboard through `mon2sb`.

### 8. Scoreboard

The scoreboard maintains an independent expected memory.

For a write, it updates the expected memory.

For a read, it compares:

```text
Expected data ↔ Actual data from DUT
```

If they match, the transaction passes. Otherwise, it fails.

## Concepts Demonstrated

- SystemVerilog classes and objects
- Transaction-based verification
- Constrained randomization
- `randomize()`
- Constraints
- Mailbox
- Generator
- Driver
- Monitor
- Scoreboard
- Interface
- Modport
- Virtual interface
- `fork...join`
- Class-to-class communication
- Class-to-hardware communication
- Hardware-to-class communication
- Read/write operations
- Expected vs actual comparison

## Concurrency

The testbench components run concurrently using:

```systemverilog
fork
    gen.run();
    drv.run();
    mon.run();
    sb.run();
join
```

This allows the generator, driver, monitor, and scoreboard to operate as independent processes.

## Verification Architecture

The important communication paths are:

### Class → Class

```text
Generator → Mailbox → Driver
```

### Class → Hardware

```text
Driver → Virtual Interface → DUT
```

### Hardware → Class

```text
DUT → Interface → Monitor → Mailbox → Scoreboard
```

## Result

The lab demonstrates a complete basic SystemVerilog verification flow without using an agent class. Randomized transactions are generated, transferred through mailboxes, driven to the DUT through a virtual interface, observed by the monitor, and finally checked by the scoreboard.
