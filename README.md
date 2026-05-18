# 🛡 Real-Time Anti-Fraud & Billing Engine
A high-performance, in-memory fraud prevention system built on Tarantool, Lua, C, and Perl. Designed to process transactions and apply complex business rules in under 1 millisecond.

# Technologies
[![Tarantool](https://img.shields.io/badge/-Tarantool-464646?style=flat-square&logo=tarantool)](https://www.tarantool.io/)
[![Lua](https://img.shields.io/badge/-Lua-464646?style=flat-square&logo=lua)](https://www.lua.org/)
[![C](https://img.shields.io/badge/-C-464646?style=flat-square&logo=c)](https://en.cppreference.com/w/c)
[![Perl](https://img.shields.io/badge/-Perl-464646?style=flat-square&logo=perl)](https://www.perl.org/)
[![Go](https://img.shields.io/badge/-Go-464646?style=flat-square&logo=go)](https://go.dev/)
[![Docker](https://img.shields.io/badge/-Docker-464646?style=flat-square&logo=docker)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Tech Stack

### Core Engine
- **Application Server**: [Tarantool](https://www.tarantool.io/) — In-memory database and application server in one address space.
- **Business Logic**: **Lua JIT** — High-performance scripting for real-time rule evaluation.
- **Heavy Math/DS**: **C (C-Extension)** — Custom Bloom Filter implementation for $O(1)$ blacklist checks.

### ETL & Integration
- **Legacy Glue**: **Perl 5** — Powerful regex and asynchronous integration layer.
- **Async Framework**: [AnyEvent](https://metacpan.org/pod/AnyEvent) — Non-blocking I/O for log ingestion.
- **Tarantool Driver**: [DR::Tarantool](https://metacpan.org/pod/DR::Tarantool) — Fast binary protocol client for Perl.

### Testing & Benchmarking
- **Unit Testing**: **TAP (Test Anything Protocol)** — Native Tarantool testing module.
- **Load Testing**: **Go** — High-concurrency benchmark tool capable of generating 50k+ TPS.

## Project Structure

```text
tarantool-antifraud-core/
├── src/
│   ├── tarantool/                 # Core Database & Logic
│   │   ├── init.lua               # Schema, Rules Engine, and API
│   │   ├── fraud_utils.c          # C-Extension (Bloom Filter)
│   │   └── Makefile               # C-module build script
│   └── perl/                      # ETL & Integration Layer
│       ├── log_ingester.pl        # Async log parser (ETL)
│       └── log_generator.pl       # Mock transaction generator
│
├── tests/
│   ├── lua/                       # Business Logic Tests
│   │   └── tests.lua              # TAP unit tests
│   └── go/                        # Performance Tests
│       ├── benchmark.go           # High-load benchmark
│       └── go.mod                 # Go dependencies
│
├── .github/                       # CI/CD Workflows
│   └── workflows/
│       └── ci.yml                 # Automated testing pipeline
│
├── README.md
└── LICENSE
```

## Quick Start

### Requirements
- Tarantool 2.10+
- Perl 5.30+ (`AnyEvent`, `DR::Tarantool`)
- Go 1.21+ (for benchmarking)
- GCC & Make

### 1. Build the C-Extension
The Bloom Filter module must be compiled into a shared library:
```bash
cd src/tarantool && make
```

### 2. Start the Anti-Fraud Engine
Run the Tarantool instance:
```bash
tarantool src/tarantool/init.lua
```

### 3. Run the ETL Ingester
In a separate terminal, start the Perl daemon to watch the transaction logs:
```bash
perl src/perl/log_ingester.pl transactions.log
```

## Anti-Fraud Rules

| Rule | Implementation | Threshold |
|------|----------------|-----------|
| **User Velocity** | Lua + Index Scan | Max 5 tx / 10 sec |
| **IP Velocity** | Lua + Index Scan | Max 5 tx / 10 sec |
| **Daily Limit** | Lua + Index Scan | 5000 units / 24h |
| **Blacklist Check**| C (Bloom Filter) | $O(1)$ bitset check |

## Architecture

The system utilizes Tarantool's **Cooperative Multitasking (Fibers)** to ensure high concurrency without the overhead of OS-level locks.

```text
[ Legacy Logs ] → [ Perl Ingester ] 
                        ↓ (Binary Protocol)
                  [ Tarantool Fiber ]
                        ↓
             ┌──────────┴──────────┐
             ↓                     ↓
      [ Lua Rules ] ←────→ [ C Bloom Filter ]
             ↓
      [ In-Memory Space ]
```

### Why this stack?
1. **Tarantool**: Eliminates network latency between DB and Logic.
2. **C-Extension**: Provides deterministic $O(1)$ checks for massive blacklists with zero GC impact.
3. **Perl**: The "Swiss Army Knife" for parsing unpredictable legacy log formats.

## Testing

### Unit Tests (Lua)
Verify business rules and edge cases:
```bash
tarantool tests/lua/tests.lua
```

### Performance Benchmark (Go)
Measure throughput and latency under high load:
```bash
cd tests/go
go run benchmark.go
```

## License
This project is licensed under the [MIT License](LICENSE).
