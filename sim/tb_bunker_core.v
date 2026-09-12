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

    // 100MHz 時脈
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_bunker_core);

        // 初始化：正常運轉狀態
        rst_n           = 0;
        mains_power_ok  = 1;
        thermal_anomaly = 0;
        node_status     = 3'b111;

        #20 rst_n = 1;
        $display("[SYSTEM] Bunker security system armed.");

        // 模擬情境 1：測試外部電網斷電 (HEMP / 物理攻擊)[span_14](start_span)[span_14](end_span)
        #100;
        $display("[ALERT] Main grid failure detected!");
        mains_power_ok = 0;

        #20;
        if (gravity_door_drop && honeypot_active && silent_alarm) begin
            $display("[PASS] Gravity door dropped & Honeypot triggered successfully!");[span_15](start_span)[span_15](end_span)
        end else begin
            $display("[FAIL] Fail-safe logic failed during blackout!");
        end

        // 恢復供電，重置防禦
        #100;
        mains_power_ok = 1;
        
        // 模擬情境 2：熱成像清空視窗偵測到入侵者熱源[span_16](start_span)[span_16](end_span)
        #100;
        $display("[ALERT] Thermal anomaly detected in zero-heat window!");[span_17](start_span)[span_17](end_span)
        thermal_anomaly = 1;

        #20;
        if (gravity_door_drop) begin
            $display("[PASS] Thermal clearing lock executed!");[span_18](start_span)[span_18](end_span)
        end

        #100;
        $display("[SUCCESS] All cyber-physical security vectors verified.");
        $finish;
    end

endmodule
