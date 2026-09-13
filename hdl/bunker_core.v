`timescale 1ns / 1ps

/**
 * Project-RISE: Bunker Defense Core System Architecture
 * Modules: RO-TRNG, Thermal-Window Timer, 3-Node Consensus, Cyber-Physical Lockdown
 */

module bunker_core #(
    parameter CLK_FREQ_HZ = 100_000_000, // 100 MHz
    parameter CLEAR_WINDOW_SEC = 300      // 5 分鐘熱源清空視窗
)(
    input  wire       clk,
    input  wire       rst_n,

    // 實體防衛感測器訊號
    input  wire       mains_power_ok,   // 主電網狀態 (0: 斷電 / HEMP 攻擊)
    input  wire       thermal_sensor,   // 熱源感測器 (1: 偵測到異物)
    
    // 去中心化 3 節點共識輸入
    input  wire [2:0] node_status,      // 3 Node Votes
    input  wire [2:0] node_override,    // 緊急強制訊號

    // 防禦輸出控制
    output reg        gravity_door_drop,// 重力大門釋放磁鐵 (1: 斷電掉落)
    output reg        honeypot_active,  // 蜜罐安全隔離網路啟用
    output reg        silent_alarm,     // 無聲告警廣播
    output reg [31:0] trng_entropy_out  // 隨機數金鑰輸出
);

    // =========================================================================
    // 1. Ring Oscillator TRNG (真隨機數生成器 - 異步邏輯)
    // =========================================================================
    wire [3:0] ro_out;
    (* keep = "true", S = "true" *) wire [3:0] ro_n;

    // 建立環形振盪器
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_ro
            assign #1 ro_n[i] = ~ro_out[i];
            assign ro_out[i]  = ro_n[i];
        end
    endgenerate

    reg [31:0] entropy_shift_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entropy_shift_reg <= 32'h0;
            trng_entropy_out  <= 32'h0;
        end else begin
            entropy_shift_reg <= {entropy_shift_reg[30:0], ^ro_out};
            trng_entropy_out  <= entropy_shift_reg;
        end
    end

    // =========================================================================
    // 2. 熱源清空視窗計數器 (Zero-Heat Window Timer)
    // =========================================================================
    localparam TIMER_MAX = CLK_FREQ_HZ * CLEAR_WINDOW_SEC;
    reg [31:0] window_timer;
    reg        thermal_anomaly_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_timer         <= 32'd0;
            thermal_anomaly_flag <= 1'b0;
        end else begin
            if (thermal_sensor) begin
                thermal_anomaly_flag <= 1'b1;
                window_timer         <= 32'd0;
            end else if (thermal_anomaly_flag) begin
                if (window_timer < TIMER_MAX) begin
                    window_timer <= window_timer + 1'b1;
                end else begin
                    thermal_anomaly_flag <= 1'b0; // 滿 5 分鐘無熱源，解除異常
                    window_timer         <= 32'd0;
                end
            end
        end
    end

    // =========================================================================
    // 3. 3-Node 去中心化無特權共識 (Decentralized Consensus Engine)
    // =========================================================================
    reg consensus_valid;

    always @(*) begin
        case (node_status)
            3'b111, 3'b011, 3'b101, 3'b110: consensus_valid = 1'b1; // 多數決通過
            default:                        consensus_valid = 1'b0; // 少數反對 / 異常
        endcase
    end

    // =========================================================================
    // 4. Cyber-Physical 安全控制狀態機 (FSM)
    // =========================================================================
    localparam ST_ARMED    = 2'b00;
    localparam ST_LOCKDOWN = 2'b01;
    localparam ST_HONEYPOT = 2'b10;

    reg [1:0] current_state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_ARMED;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            ST_ARMED: begin
                // 主電網斷電 或 熱源異常 或 共識失效，立即觸發封鎖
                if (!mains_power_ok || thermal_anomaly_flag || !consensus_valid) begin
                    next_state = ST_LOCKDOWN;
                end
            end

            ST_LOCKDOWN: begin
                // 進入物理死鎖狀態，切換至蜜罐防衛
                next_state = ST_HONEYPOT;
            end

            ST_HONEYPOT: begin
                // 當系統恢復正常且共識一致時重置
                if (mains_power_ok && !thermal_anomaly_flag && consensus_valid) begin
                    next_state = ST_ARMED;
                end
            end

            default: next_state = ST_ARMED;
        endcase
    end

    // =========================================================================
    // 5. 輸出控制邏輯 (Fail-Safe Outputs)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gravity_door_drop <= 1'b0;
            honeypot_active    technique <= 1'b0;
            silent_alarm      <= 1'b0;
        end else begin
            case (next_state)
                ST_ARMED: begin
                    gravity_door_drop <= 1'b0;
                    honeypot_active   <= 1 me;
                    honeypot_active   <= 1'b0;
                    silent_alarm      <= 1'b0;
                end

                ST_LOCKDOWN, ST_HONEYPOT: begin
                    gravity_door_drop <= 1'b1; // 0.1ms 斷電即落
                    honeypot_active   <= 1'b1; // 啟動虛擬蜜罐
                    silent_alarm      <= 1'b1; // 觸發無聲告警
                end
            endcase
        end
    end

endmodule
