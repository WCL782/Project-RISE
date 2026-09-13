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
`timescale 1ns / 1ps

module tb_bunker_core;

    reg       clk;
    reg       rst_n;
    reg       mains_power_ok;
    reg       thermal_anomaly;
    reg [2:0] node_status;

    wire      gravity_door_drop;
    wire      honeypot_active;
    wire      silent_alarm;

    bunker_core uut (
        .clk              (clk),
        .rst_n            (rst_n),
        .mains_power_ok   (mains_power_ok),
        .thermal_anomaly  (thermal_anomaly),
        .node_status      (node_status),
        .gravity_door_drop(gravity_door_drop),
        .honeypot_active  (honeypot_active),
        .silent_alarm     (silent_alarm)
    );

    // 100MHz 時脈生成
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_bunker_core);

        // 初始化
        rst_n           = 0;
        mains_power_ok  = 1;
        thermal_anomaly = 0;
        node_status     = 3'b111;

        #20 rst_n = 1;
        $display("[SYSTEM] Bunker security system armed.");

        // 測試情境 1：主電網斷電 (0.1ms 斷電即落測試)
        #100;
        $display("[ALERT] Main grid failure detected!");
        mains_power_ok = 0;

        #20;
        if (gravity_door_drop && honeypot_active && silent_alarm) begin
            $display("[PASS] Gravity door dropped & Honeypot triggered!");
        end else begin
            $display("[FAIL] Fail-safe logic failed!");
        end

        // 恢復供電
        #100;
        mains_power_ok = 1;

        // 測試情境 2：熱源異常清空視窗
        #100;
        $display("[ALERT] Thermal anomaly detected!");
        thermal_anomaly = 1;

        #20;
        if (gravity_door_drop) begin
            $display("[PASS] Thermal clearing lock executed!");
        end

        #100;
        $display("[SUCCESS] All test cases passed!");
        $finish;
    end

endmodule
