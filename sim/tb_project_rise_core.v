// =========================================================================
// Project-RISE Self-Checking Testbench v4 (2-Space Standard)
// Architect: Chali Wang
// Features: Comprehensive Scenario Coverage & Automated Assertions for CI
// =========================================================================

`timescale 1ns / 1ps

module tb_project_rise_core;

  // 1. Clock & System Controls
  reg        clk;
  reg        rst_n;
  reg        mains_power_ok;
  reg        thermal_sensor;
  reg        tamper_mesh_ok;

  // 2. Interfaces
  reg [31:0] pqc_ch0_data, pqc_ch1_data, pqc_ch2_data;
  reg [2:0]  node_status;
  reg [31:0] data_in;

  wire [31:0] data_out;
  wire        pin_non_threat_alarm;
  wire        pin_decoy_trigger;
  wire        pin_quantum_start;
  wire        pin_physical_power_off;
  wire [31:0] trng_entropy_out;

  // 測試計數器
  integer test_pass_count = 0;
  integer test_fail_count = 0;

  // 實例化待測核心 (DUT)
  project_rise_core #(
    .WINDOW_THRESHOLD(32'd20),
    .QKD_TIMEOUT(32'd30)
  ) uut (
    .clk(clk),
    .rst_n(rst_n),
    .mains_power_ok(mains_power_ok),
    .thermal_sensor(thermal_sensor),
    .tamper_mesh_ok(tamper_mesh_ok),
    .pqc_ch0_data(pqc_ch0_data),
    .pqc_ch1_data(pqc_ch1_data),
    .pqc_ch2_data(pqc_ch2_data),
    .node_status(node_status),
    .data_in(data_in),
    .data_out(data_out),
    .pin_non_threat_alarm(pin_non_threat_alarm),
    .pin_decoy_trigger(pin_decoy_trigger),
    .pin_quantum_start(pin_quantum_start),
    .pin_physical_power_off(pin_physical_power_off),
    .trng_entropy_out(trng_entropy_out)
  );

  // 時脈產生 (100MHz => 週期 10ns)
  initial clk = 0;
  always #5 clk = ~clk;

  // 自訂斷言 Task：檢查訊號狀態
  task check_signal;
    input [256:1] test_name;
    input         actual_value;
    input         expected_value;
    begin
      if (actual_value === expected_value) begin
        $display("[PASS] %s | Expected: %b, Got: %b", test_name, expected_value, actual_value);
        test_pass_count = test_pass_count + 1;
      end else begin
        $display("[FAIL] %s | Expected: %b, Got: %b << ERROR!", test_name, expected_value, actual_value);
        test_fail_count = test_fail_count + 1;
      end
    end
  endtask

  // 主測試程序
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_project_rise_core);

    $display("=================================================");
    $display("   Project-RISE Hardware Verification Suite v4");
    $display("=================================================");

    // --- 初始化狀態 ---
    rst_n          = 0;
    mains_power_ok = 1;
    thermal_sensor = 0;
    tamper_mesh_ok = 1; // 防拆網格正常
    pqc_ch0_data   = 32'hA5A5_1234;
    pqc_ch1_data   = 32'hA5A5_1234;
    pqc_ch2_data   = 32'hA5A5_1234;
    node_status    = 3'b111; // 3/3 共識
    data_in        = 32'h0;

    #20 rst_n = 1; #10;
    $display("\n--- TEST 1: Initial System Armed Check ---");
    check_signal("Physical Power Off Output", pin_physical_power_off, 1'b0);
    check_signal("Decoy Trigger Output",       pin_decoy_trigger,      1'b0);

    // --- TEST 2: TMR Fault & Decoy Mode ---
    $display("\n--- TEST 2: TMR Channel Fault (Decoy Trigger) ---");
    pqc_ch2_data = 32'hDEAD_BEEF; // CH2 故障
    #20;
    check_signal("Decoy Trigger Activated",    pin_decoy_trigger,      1'b1);
    check_signal("Non-Threat Alarm Triggered", pin_non_threat_alarm,   1'b1);

    // 恢復 TMR 正常
    pqc_ch2_data = 32'hA5A5_1234; #20;

    // --- TEST 3: Tamper Mesh Physical Security ---
    $display("\n--- TEST 3: Physical Enclosure Tamper Detection ---");
    tamper_mesh_ok = 0; // 模擬實體外殼被破壞
    #20;
    check_signal("Tamper Lockdown Power Sever", pin_physical_power_off, 1'b1);
    check_signal("Bus Zeroization Masking",      (data_out == 32'h0),    1'b1);

    // 復位測試其餘項
    rst_n = 0; #20; rst_n = 1; tamper_mesh_ok = 1; #20;

    // --- TEST 4: Power Loss Simulation ---
    $display("\n--- TEST 4: Mains Power Loss (HEMP Simulation) ---");
    mains_power_ok = 0; #20;
    check_signal("Power Cut Instant Lockdown", pin_physical_power_off, 1'b1);

    // --- TEST 5: 8-Channel RO-TRNG Output Check ---
    $display("\n--- TEST 5: RO-TRNG Entropy Generation Check ---");
    #50;
    if (trng_entropy_out !== 32'h0 && trng_entropy_out !== 32'hFFFF_FFFF) begin
      $display("[PASS] 8-CH TRNG Generated Entropy: 0x%h", trng_entropy_out);
      test_pass_count = test_pass_count + 1;
    end else begin
      $display("[FAIL] TRNG Output Invalid: 0x%h << ERROR!", trng_entropy_out);
      test_fail_count = test_fail_count + 1;
    end

    // --- 總結報告 ---
    $display("\n=================================================");
    $display("   Simulation Summary Report");
    $display("   PASS: %0d | FAIL: %0d", test_pass_count, test_fail_count);
    $display("=================================================");

    if (test_fail_count > 0) begin
      $display(">>> TEST SUITE FAILED! Triggering CI Failure. <<<");
      $stop;
    end else begin
      $display(">>> ALL TESTS PASSED SUCCESSFULLY! <<<");
      $finish;
    end
  end

endmodule
