// =========================================================================
// Project-RISE Sovereign-Grade Defense Core (v3.5 Competition Edition)
// Architect: Chali Wang
// License: MIT
// =========================================================================

module project_rise_core #(
    parameter WINDOW_THRESHOLD = 32'd250000, // Scaled threshold for emulation
    parameter QKD_TIMEOUT      = 32'd180000  // Evaporation Cycle Limit
)(
    input  wire        clk,
    input  wire        rst_n,

    // TMR Sensor Interfaces
    input  wire [31:0] pqc_ch0_data, input wire pqc_ch0_valid,
    input  wire [31:0] pqc_ch1_data, input wire pqc_ch1_valid,
    input  wire [31:0] pqc_ch2_data, input wire pqc_ch2_valid,

    // High-Assurance Data Bus
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,

    // Control & Relay Trigger Outputs
    output reg         pin_non_threat_alarm,
    output reg         pin_decoy_trigger,
    output reg         pin_quantum_start,
    output reg         pin_physical_power_off
);

    // =========================================================================
    // 1. Triple Modular Redundancy (TMR) Sensor Majority Voter
    // =========================================================================
    wire [31:0] voted_pqc_data = (pqc_ch0_data & pqc_ch1_data) | 
                                 (pqc_ch1_data & pqc_ch2_data) | 
                                 (pqc_ch0_data & pqc_ch2_data);
    
    wire voted_pqc_valid = (pqc_ch0_valid & pqc_ch1_valid) | 
                           (pqc_ch1_valid & pqc_ch2_valid) | 
                           (pqc_ch0_valid & pqc_ch2_valid);

    wire pin_optical_fail    = voted_pqc_valid ? voted_pqc_data[0] : 1'b0;
    wire pin_spatial_anomaly = voted_pqc_valid ? voted_pqc_data[1] : 1'b0;
    wire pin_bio_stress      = voted_pqc_valid ? voted_pqc_data[2] : 1'b0;

    wire [1:0] active_anomalies = pin_optical_fail + pin_spatial_anomaly + pin_bio_stress;

    // =========================================================================
    // 2. Hardware RO-TRNG Entropy Source (Asymmetric Ring Oscillators)
    // =========================================================================
    wire ro1_out, ro2_out;

    // RO Ring 1 (3-stage Loop with synthesis attributes)
    (* keep = "true", S = "true" *) wire [2:0] ro1_nodes;
    assign ro1_nodes[0] = ~ro1_nodes[2];
    assign ro1_nodes[1] = ~ro1_nodes[0];
    assign ro1_nodes[2] = ~ro1_nodes[1];
    assign ro1_out      =  ro1_nodes[2];

    // RO Ring 2 (5-stage Loop)
    (* keep = "true", S = "true" *) wire [4:0] ro2_nodes;
    assign ro2_nodes[0] = ~ro2_nodes[4];
    assign ro2_nodes[1] = ~ro2_nodes[0];
    assign ro2_nodes[2] = ~ro2_nodes[1];
    assign ro2_nodes[3] = ~ro2_nodes[2];
    assign ro2_nodes[4] = ~ro2_nodes[3];
    assign ro2_out      =  ro2_nodes[4];

    // Metastability Sampling Register
    reg [31:0] trng_entropy_pool;
    reg        sampler_ff1, sampler_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sampler_ff1       <= 1'b0;
            sampler_ff2       <= 1'b0;
            trng_entropy_pool <= 32'hDEADBEEF;
        end else begin
            sampler_ff1       <= ro1_out ^ ro2_out;
            sampler_ff2       <= sampler_ff1; 
            trng_entropy_pool <= {trng_entropy_pool[30:0], sampler_ff2};
        end
    end

    wire [3:0] trng_val  = (trng_entropy_pool[3:0] % 4'd10) + 4'd1; // Range [1..10]
    wire       trng_sign = trng_entropy_pool[4];

    // =========================================================================
    // 3. TMR State Machine & Spatio-Temporal Filtering Window
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
    // 4. Crypto Interface & Dynamic Precision Sabotage
    // =========================================================================
    wire [31:0] encrypted_payload = data_in ^ 32'hDEAD_BEEF; // Crypto Datapath Model
    reg  [31:0] pipe_stage1_data;
    reg  [31:0] pipe_stage2_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_stage1_data <= 32'd0;
            pipe_stage2_data <= 32'd0;
            data_out         <= 32'd0;
        end else begin
            if (current_state == S_SECURE) begin
                pipe_stage1_data <= encrypted_payload;
                pipe_stage2_data <= pipe_stage1_data;
            end else if (current_state == S_MELTDOWN) begin
                pipe_stage1_data <= data_in;
                if (trng_sign)
                    pipe_stage2_data <= pipe_stage1_data + {28'd0, trng_val};
                else
                    pipe_stage2_data <= pipe_stage1_data - {28'd0, trng_val};
            end else begin
                pipe_stage1_data <= data_in;
                pipe_stage2_data <= pipe_stage1_data;
            end

            data_out <= pipe_stage2_data;
        end
    end

    // Relay Control Outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pin_non_threat_alarm   <= 1'b0;
            pin_decoy_trigger      <= 1'b0;
            pin_quantum_start      <= 1'b0;
            pin_physical_power_off <= 1'b0;
        end else begin
            pin_non_threat_alarm <= (active_anomalies >= 2'b01);

            if (current_state == S_MELTDOWN) begin
                pin_decoy_trigger <= 1'b1;
                pin_quantum_start <= 1'b1;

                if (bram_scrub_counter >= 8'd254)
                    pin_physical_power_off <= 1'b1;
            end else begin
                pin_decoy_trigger      <= 1'b0;
                pin_quantum_start      <= 1'b0;
                pin_physical_power_off <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 5. Formal Verification Assertions (SVA)
    // =========================================================================
`ifdef FORMAL
    // Assertion 1: State Machine Invariance
    assert property (@(posedge clk) 
        (current_state == S_SECURE) || (current_state == S_ALERT) || (current_state == S_MELTDOWN)
    );

    // Assertion 2: Direct Jump To Meltdown Illegal
    property p_no_instant_meltdown;
        @(posedge clk) disable iff (!rst_n)
        (current_state == S_SECURE) ##1 (current_state == S_MELTDOWN) |==> 1'b0;
    endproperty
    assert property (p_no_instant_meltdown);
`endif

endmodule
