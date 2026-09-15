name: Project-RISE High-Assurance Verification Pipeline

on:
  workflow_dispatch:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]

jobs:
  lint-analysis:
    name: 1. RTL Static Analysis & Strict Linting
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Install Verilator
        run: |
          sudo apt-get update -y
          sudo apt-get install -y verilator

      - name: Run Verilator Lint
        run: make lint

  synthesis-check:
    name: 2. Hardware Synthesizability Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Install Yosys
        run: |
          sudo apt-get update -y
          sudo apt-get install -y yosys

      - name: Run Yosys Synthesis Check
        run: make synth

  rtl-simulation:
    name: 3. RTL Simulation & Threat Verification
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Install Icarus Verilog
        run: |
          sudo apt-get update -y
          sudo apt-get install -y iverilog vvp

      - name: Run Icarus Simulation
        run: make sim

  hal-driver-test:
    name: 4. C++ Hardware Abstraction Layer Verification
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Install C++ Toolchain
        run: |
          sudo apt-get update -y
          sudo apt-get install -y build-essential gcc g++

      - name: Run C++ HAL Driver Verification
        run: make hal
