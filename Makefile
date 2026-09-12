name: Project-RISE Hardware Verification CI

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]

jobs:
  iverilog-build-and-test:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Source
      uses: actions/checkout@v4

    - name: Install Icarus Verilog
      run: |
        sudo apt-get update
        sudo apt-get install -y iverilog build-essential

    - name: Run Hardware Simulation
      run: |
        FILES=$(find . -maxdepth 3 -name "*.v")
        echo "Found Verilog files:"
        echo "$FILES"
        iverilog -o sim.vvp $FILES
        vvp sim.vvp
