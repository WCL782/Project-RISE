#include <iostream>
#include <cassert>
#include <cstdlib>
#include <cmath>
#include <verilated.h>
#include "Vproject_rise_core.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vproject_rise_core* top = new Vproject_rise_core;

    // Reset Sequence
    top->clk = 0; top->rst_n = 0; top->eval();
    top->clk = 1; top->rst_n = 1; top->eval();

    std::cout << "[TEST 1] Testing Secure Mode Crypto Datapath..." << std::endl;
    top->data_in = 0x12345678;
    for (int i = 0; i < 2; ++i) {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
    }
    assert(top->data_out == (0x12345678 ^ 0xDEADBEEF));
    std::cout << " -> PASSED: Secure Mode Encryption Verified." << std::endl;

    std::cout << "[TEST 2] Testing TMR Majority Voting..." << std::endl;
    top->pqc_ch0_data = 0x01; top->pqc_ch0_valid = 1;
    top->pqc_ch1_data = 0x01; top->pqc_ch1_valid = 1;
    top->pqc_ch2_data = 0x00; top->pqc_ch2_valid = 1;

    top->clk = 0; top->eval(); top->clk = 1; top->eval();
    assert(top->pin_non_threat_alarm == 1);
    assert(top->pin_decoy_trigger == 0);
    std::cout << " -> PASSED: TMR Anomaly Filter Correct." << std::endl;

    std::cout << "[TEST 3] Testing Multi-Vector Threat Saturation..." << std::endl;
    top->pqc_ch0_data = 0x03;
    top->pqc_ch1_data = 0x03;
    top->pqc_ch2_data = 0x03;

    for (int i = 0; i < 250005; ++i) {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
    }
    assert(top->pin_decoy_trigger == 1);
    assert(top->pin_quantum_start == 1);
    std::cout << " -> PASSED: Meltdown State Latched Successfully." << std::endl;

    std::cout << "[TEST 4] Testing Physical RO-TRNG Sabotage (1000 Cycles)..." << std::endl;
    int sabotage_pass = 0;
    for (int i = 0; i < 1000; ++i) {
        uint32_t sample_in = rand() % 500000 + 1000;
        top->data_in = sample_in;

        for (int step = 0; step < 2; ++step) {
            top->clk = 0; top->eval();
            top->clk = 1; top->eval();
        }

        uint32_t sample_out = top->data_out;
        int diff = std::abs((int)sample_out - (int)sample_in);

        if (diff >= 1 && diff <= 10) sabotage_pass++;
    }
    std::cout << " -> Sabotage Accuracy: " << sabotage_pass << "/1000 Cycles Passed." << std::endl;
    assert(sabotage_pass == 1000);

    std::cout << "[TEST 5] Testing Active BRAM Scrubbing & Power Cutoff..." << std::endl;
    for (int i = 0; i < 180300; ++i) {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
    }
    assert(top->pin_physical_power_off == 1);
    std::cout << " -> PASSED: Physical Power Off Relay Executed." << std::endl;

    std::cout << "\n=================================================" << std::endl;
    std::cout << " ALL PROJECT-RISE COMPETITION TESTS PASSED!      " << std::endl;
    std::cout << "=================================================" << std::endl;

    delete top;
    return 0;
}
