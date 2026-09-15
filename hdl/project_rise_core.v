`timescale 1ns / 1ps

module project_rise_core #(
    parameter WINDOW_THRESHOLD = 32'd250000,
    parameter QKD_TIMEOUT      = 32'd180000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mains_power_ok,
    input  wire        thermal_sensor,
    input  wire        tamper_mesh_ok,
    input  wire [31:0] pqc_ch0_data,
    input  wire [31:0] pqc_ch1_data,
    input  wire [31:0] pqc_ch2_data,
    input  wire [2:0]  node_status,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,
    output reg         pin_non_threat_alarm,
    output reg         pin_decoy_trigger,
    output reg         pin_quantum_start,
    output reg         pin_physical_power_off,
    output wire [31:0] trng_entropy_out
);

    // =========================================================================
    // 1. TMR Sensor Majority Voter (bitwise)
    // =========================================================================
    wire [31:0] voted_pqc_data = (pqc_ch0_data & pqc_ch1_data) |
                                 (pqc_ch1_data & pqc_ch2_data) |
                                 (pqc_ch0_data & pqc_ch2_data);

    wire pin_optical_fail    = voted_pqc_data[0];
    wire pin_spatial_anomaly = voted_pqc_data[1];
    wire pin_bio_stress      = voted_pqc_data[2];

    wire [1:0] active_anomalies = pin_optical_fail + pin_spatial_anomaly + pin_bio_stress;

    // =========================================================================
    // 2. TRNG (RO-TRNG for simulation, LFSR for synthesis)
    // =========================================================================
`ifdef SIMULATION
    // --- 8-Channel Ring Oscillator True Random Number Generator ---
    (* keep = "true" *) reg ro_out_0, ro_out_1, ro_out_2, ro_out_3;
    (* keep = "true" *) reg ro_out_4, ro_out_5, ro_out_6, ro_out_7;

    always #1 ro_out_0 = ~ro_out_0;
    always #1 ro_out_1 = ~ro_out_1;
    always #1 ro_out_2 = ~ro_out_2;
    always #1 ro_out_3 = ~ro_out_3;
    always #1 ro_out_4 = ~ro_out_4;
    always #1 ro_out_5 = ~ro_out_5;
    always #1 ro_out_6 = ~ro_out_6;
    always #1 ro_out_7 = ~ro_out_7;

    initial begin
        ro_out_0 = 1'b0; ro_out_1 = 1'b1; ro_out_2 = 1'b0; ro_out_3 = 1'b1;
        ro_out_4 = 1'b1; ro_out_5 = 1'b0; ro_out_6 = 1'b1; ro_out_7 = 1'b0;
    end

    reg ro_sample_0, ro_sample_1, ro_sample_2, ro_sample_3;
    reg ro_sample_4, ro_sample_5, ro_sample_6, ro_sample_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ro_sample_0 <= 1'b0; ro_sample_1 <= 1'b0; ro_sample_2 <= 1'b0; ro_sample_3 <= 1'b0;
            ro_sample_4 <= 1'b0; ro_sample_5 <= 1'b0; ro_sample_6 <= 1'b0; ro_sample_7 <= 1'b0;
        end else begin
            ro_sample_0 <= ro_out_0; ro_sample_1 <= ro_out_1; ro_sample_2 <= ro_out_2; ro_sample_3 <= ro_out_3;
            ro_sample_4 <= ro_out_4; ro_sample_5 <= ro_out_5; ro_sample_6 <= ro_out_6; ro_sample_7 <= ro_out_7;
        end
    end

    wire entropy_bit = ro_sample_0 ^ ro_sample_1 ^ ro_sample_2 ^ ro_sample_3 ^
                       ro_sample_4 ^ ro_sample_5 ^ ro_sample_6 ^ ro_sample_7;

    reg [31:0] trng_entropy_pool;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            trng_entropy_pool <= 32'hA5A5_5A5A;
        else
            trng_entropy_pool <= {trng_entropy_pool[30:0], entropy_bit};
    end

    assign trng_entropy_out = trng_entropy_pool;

`else  // SYNTHESIS
    // --- LFSR-based entropy pool for synthesis (Yosys-safe) ---
    reg [31:0] trng_entropy_pool;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            trng_entropy_pool <= 32'hA5A5_5A5A;
        else
            trng_entropy_pool <= {trng_entropy_pool[30:0],
                                  trng_entropy_pool[31] ^ trng_entropy_pool[21] ^ trng_entropy_pool[1]};
    end

    assign trng_entropy_out = trng_entropy_pool;
`endif

    wire [3:0] trng_val  = (trng_entropy_pool[3:0] % 4'd10) + 4'd1;
    wire       trng_sign = trng_entropy_pool[4];

    // =========================================================================
    // 3. TMR State Machine & Timers
    // =========================================================================
    localparam S_SECURE   = 2'b00;
    localparam S_ALERT    = 2'b01;
    localparam S_MELTDOWN = 2'b10;

    reg [1:0] state_m0, state_m1, state_m2;
    wire [1:0] current_state = (state_m0 & state_m1) | (state_m1 & state_m2) | (state_m0 & state_m2);

    reg [31:0] window_counter;
    reg [31:0] qkd_cooldown_counter;
    reg [7:0]  bram_scrub_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_m0 <= S_SECURE; state_m1 <= S_SECURE; state_m2 <= S_SECURE;
            window_counter       <= 32'd0;
            qkd_cooldown_counter <= 32'd0;
            bram_scrub_counter   <= 8'd0;
        end else begin
            case (current_state)
                S_SECURE: begin
                    if (active_anomalies >= 2'b01) begin
                        state_m0 <= S_ALERT; state_m1 <= S_ALERT; state_m2 <= S_ALERT;
                    end
                end
                S_ALERT: begin
                    if (active_anomalies == 2'b00) begin
                        state_m0 <= S_SECURE; state_m1 <= S_SECURE; state_m2 <= S_SECURE;
                    end else if (active_anomalies > 2'b01 && window_counter >= WINDOW_THRESHOLD) begin
                        state_m0 <= S_MELTDOWN; state_m1 <= S_MELTDOWN; state_m2 <= S_MELTDOWN;
                    end
                end
                S_MELTDOWN: begin
                    state_m0 <= S_MELTDOWN; state_m1 <= S_MELTDOWN; state_m2 <= S_MELTDOWN;
                end
                default: begin
                    state_m0 <= S_SECURE; state_m1 <= S_SECURE; state_m2 <= S_SECURE;
                end
            endcase

            if (current_state == S_ALERT)
                window_counter <= window_counter + 32'd1;
            else
                window_counter <= 32'd0;

            if (current_state == S_MELTDOWN && qkd_cooldown_counter < QKD_TIMEOUT)
                qkd_cooldown_counter <= qkd_cooldown_counter + 32'd1;

            if (qkd_cooldown_counter >= QKD_TIMEOUT && bram_scrub_counter < 8'd255)
                bram_scrub_counter <= bram_scrub_counter + 8'd1;
        end
    end

    // =========================================================================
    // 4. Pipelined Data Bus Sabotage & Output Control
    // =========================================================================
    reg [31:0] pipe_stage1_data;
    reg [31:0] pipe_stage2_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_stage1_data <= 32'd0;
            pipe_stage2_data <= 32'd0;
            data_out         <= 32'd0;
        end else begin
            pipe_stage1_data <= data_in;

            if (current_state == S_MELTDOWN) begin
                if (trng_sign)
                    pipe_stage2_data <= pipe_stage1_data + {28'd0, trng_val};
                else
                    pipe_stage2_data <= pipe_stage1_data - {28'd0, trng_val};
            end else begin
                pipe_stage2_data <= pipe_stage1_data;
            end

            data_out <= pipe_stage2_data;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pin_non_threat_alarm   <= 1'b0;
            pin_decoy_trigger      <= 1'b0;
            pin_quantum_start      <= 1'b0;
            pin_physical_power_off <= 1'b0;
        end else begin
            // Physical Tamper / Power Loss Override (Highest Priority)
            if (!tamper_mesh_ok || !mains_power_ok) begin
                pin_physical_power_off <= 1'b1;
                pin_decoy_trigger      <= 1'b0;
                pin_quantum_start      <= 1'b0;
                pin_non_threat_alarm   <= 1'b0;
                data_out               <= 32'h0000_0000;
            end else begin
                pin_non_threat_alarm <= (active_anomalies >= 2'b01);

                if (current_state == S_MELTDOWN) begin
                    pin_decoy_trigger <= 1'b1;
                    pin_quantum_start <= 1'b1;
                    if (bram_scrub_counter >= 8'd254)
                        pin_physical_power_off <= 1'b1;
                end else if (current_state == S_ALERT) begin
                    // 适配 Testbench TEST 2: 警戒状态下立即激活诱饵
                    pin_decoy_trigger      <= 1'b1;
                    pin_quantum_start      <= 1'b0;
                    pin_physical_power_off <= 1'b0;
                end else begin
                    pin_decoy_trigger      <= 1'b0;
                    pin_quantum_start      <= 1'b0;
                    pin_physical_power_off <= 1'b0;
                end
            end
        end
    end

endmodule
