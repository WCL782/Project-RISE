`timescale 1ns / 1ps

module bunker_core (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       mains_power_ok,   // 主電網狀態 (0: 斷電)[span_2](start_span)[span_2](end_span)
    input  wire       thermal_anomaly,  // 熱源異常 (1: 偵測到異物)[span_3](start_span)[span_3](end_span)
    input  wire [2:0] node_status,      // 3個去中心化節點狀態[span_4](start_span)[span_4](end_span)
    output reg        gravity_door_drop,// 重力大門釋放訊號 (1: 掉落)[span_5](start_span)[span_5](end_span)
    output reg        honeypot_active,  // 蜜罐模式開啟[span_6](start_span)[span_6](end_span)
    output reg        silent_alarm      // 無聲告警[span_7](start_span)[span_7](end_span)
);

    // 1. 重力大門掉落邏輯：主電網切斷 或 熱源異常 時 0.1ms 內失去磁力掉落[span_8](start_span)[span_8](end_span)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gravity_door_drop <= 1'b0;
            honeypot_active   <= 1'b0;
            silent_alarm      <= 1'b0;
        end else begin
            if (!mains_power_ok || thermal_anomaly) begin
                gravity_door_drop <= 1'b1; // 物理死鎖[span_9](start_span)[span_9](end_span)
                honeypot_active   <= 1'b1; // 切換至虛擬蜜罐[span_10](start_span)[span_10](end_span)
                silent_alarm      <= 1'b1; // 無聲告警通知外部部隊[span_11](start_span)[span_11](end_span)
            end
        end
    end

    // 2. 去中心化 3 節點多數決共識 (1 Node = 1 Vote，無 Admin)[span_12](start_span)[span_12](end_span)
    wire consensus_ok;
    assign consensus_ok = (node_status == 3'b111) || 
                         (node_status == 3'b011) || 
                         (node_status == 3'b101) || 
                         (node_status == 3'b110);

endmodule
