// =========================================================================
// Project-RISE Sovereign-Grade Defense Core v4 (2-Space Standard)
// Architect: Chali Wang
// License: MIT
// Modules: Advanced TMR, Dynamic Thermal Windowing, Fault-Tolerant RO-TRNG,
//          Multi-Phase QKD FSM, Anti-Tamper Honeygrid Decoy, Fail-Safe Lockdown
// =========================================================================

`timescale 1ns / 1ps

module project_rise_core #(
  parameter WINDOW_THRESHOLD = 32'd250000,   // Dynamic Thermal Window Threshold
  parameter QKD_TIMEOUT      = 32'd180000    // QKD Key Synchronization Timeout
)(
  input  wire        clk,
  input  wire        rst_n,

  // Environmental & Power Sensors
  input  wire        mains_power_ok,         // Mains Power Status (0: Cut / HEMP Attack)
  input  wire        thermal_sensor,         // Thermal Anomaly Sensor (1: Intruder Detected)
  input  wire        tamper_mesh_ok,         // Physical Enclosure Tamper Mesh Sensor

  // Triple Modular Redundancy (TMR) Sensor Interfaces
  input  wire [31:0] pqc_ch0_data,
  input  wire [31:0] pqc_ch1_data,
  input  wire [31:0] pqc_ch2_data,

  // 3-Node Decentralized Zero-Trust Consensus Inputs
  input  wire [2:0]  node_status,            // 3 Node Active Votes (No Admin Root)

  // High-Assurance Secure Bus Interface
  input  wire [31:0] data_in,
  output reg  [31:0] data_out,

  // Defense Real-Time Relays & Output Controls
  output reg         pin_non_threat_alarm,   // Silent Warning Signal
  output reg         pin_decoy_trigger,      // Honeypot Decoy Activation Trigger
  output reg         pin_quantum_start,      // Quantum Key Distribution Start
  output reg         pin_physical_power_off, // Instant Physical Lockdown & Power Sever
  output reg [31:0]  trng_entropy_out        // True Random Number Generator Key Stream
);

  // 1. Advanced Triple Modular Redundancy (TMR) Majority Voter & Diagnostics
  reg [31:0] tmr_voted_data;
  reg [2:0]  tmr_channel_faults;
  reg        tmr_fault_detected;

  always @(*) begin
    tmr_channel_faults = 3'b000;
    if (pqc_ch0_data == pqc_ch1_data) begin
      tmr_voted_data = pqc_ch0_data;
      if (pqc_ch0_data != pqc_ch2_data) tmr_channel_faults[2] = 1'b1;
    end else if (pqc_ch0_data == pqc_ch2_data) begin
      tmr_voted_data = pqc_ch0_data;
      tmr_channel_faults[1] = 1'b1;
    end else if (pqc_ch1_data == pqc_ch2_data) begin
      tmr_voted_data = pqc_ch1_data;
      tmr_channel_faults[0] = 1'b1;
    end else begin
      tmr_voted_data = pqc_ch0_data;
      tmr_channel_faults = 3'b111;
    end
    tmr_fault_detected = (tmr_channel_faults != 3'b000);
  end

  // 2. Dynamic Thermal Windowing & Anomaly Accumulator
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
        if (window_timer < WINDOW_THRESHOLD) begin
          window_timer <= window_timer + 1'b1;
        end else begin
          thermal_anomaly_flag <= 1'b0;
          window_timer         <= 32'd0;
        end
      end
    end
  end

  // 3. Decentralized 3-Node Majority Voting Logic
  reg consensus_ok;

  always @(*) begin
    case (node_status)
      3'b111, 3'b011, 3'b101, 3'b110: consensus_ok = 1'b1;
      default:                        consensus_ok = 1'b0;
    endcase
  end

  // 4. Multi-Stage Ring Oscillator True Random Number Generator (RO-TRNG)
  /* verilator lint_off UNOPTFLAT */
  wire [7:0] ro_out;
  wire [7:0] ro_n;

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_ro
      assign ro_n[i]   = ~ro_out[i];
      assign ro_out[i] = ro_n[i];
    end
  endgenerate
  /* verilator lint_on UNOPTFLAT */

  reg [31:0] entropy_reg;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      entropy_reg      <= 32'hA5A5_5A5A;
      trng_entropy_out <= 32'h0;
    end else begin
      entropy_reg      <= {entropy_reg[23:0], ^ro_out[3:0], ^ro_out[7:4], ro_out[1] ^ ro_out[5], ro_out[2] ^ ro_out[6]};
      trng_entropy_out <= entropy_reg;
    end
  end

  // 5. Mission-Critical Defense & QKD Sync State Machine (FSM)
  localparam ST_INIT       = 3'b000;
  localparam ST_ARMED      = 3'b001;
  localparam ST_QKD_SYNC   = 3'b010;
  localparam ST_DECOY_ACT  = 3'b011;
  localparam ST_LOCKDOWN   = 3'b100;

  reg [2:0]  current_state, next_state;
  reg [31:0] qkd_timer;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= ST_INIT;
      qkd_timer     <= 32'd0;
    end else begin
      current_state <= next_state;
      if (current_state == ST_QKD_SYNC) begin
        qkd_timer <= qkd_timer + 1'b1;
      end else begin
        qkd_timer <= 32'd0;
      end
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      ST_INIT: begin
        next_state = ST_ARMED;
      end

      ST_ARMED: begin
        if (!mains_power_ok || !consensus_ok || thermal_anomaly_flag || !tamper_mesh_ok) begin
          next_state = ST_LOCKDOWN;
        end else if (tmr_fault_detected) begin
          next_state = ST_DECOY_ACT;
        end else if (window_timer >= WINDOW_THRESHOLD) begin
          next_state = ST_QKD_SYNC;
        end
      end

      ST_QKD_SYNC: begin
        if (qkd_timer >= QKD_TIMEOUT || !tamper_mesh_ok) begin
          next_state = ST_LOCKDOWN;
        end else if (data_in == 32'h0000_0000) begin
          next_state = ST_ARMED;
        end
      end

      ST_DECOY_ACT: begin
        if (!tmr_fault_detected) begin
          next_state = ST_ARMED;
        end else if (thermal_anomaly_flag || !mains_power_ok || !tamper_mesh_ok) begin
          next_state = ST_LOCKDOWN;
        end
      end

      ST_LOCKDOWN: begin
        next_state = ST_LOCKDOWN;
      end

      default: next_state = ST_INIT;
    endcase
  end

  // 6. Fail-Safe Output Registers & Real-Time Dynamic Masking
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out               <= 32'd0;
      pin_non_threat_alarm   <= 1'b0;
      pin_decoy_trigger      <= 1'b0;
      pin_quantum_start      <= 1'b0;
      pin_physical_power_off <= 1'b0;
    end else begin
      data_out <= (current_state == ST_LOCKDOWN) ? 32'h0000_0000 : (tmr_voted_data ^ entropy_reg);

      case (current_state)
        ST_INIT, ST_ARMED: begin
          pin_non_threat_alarm   <= 1'b0;
          pin_decoy_trigger      <= 1'b0;
          pin_quantum_start      <= 1'b0;
          pin_physical_power_off <= 1'b0;
        end

        ST_QKD_SYNC: begin
          pin_non_threat_alarm   <= 1'b0;
          pin_decoy_trigger      <= 1'b0;
          pin_quantum_start      <= 1'b1;
          pin_physical_power_off <= 1'b0;
        end

        ST_DECOY_ACT: begin
          pin_non_threat_alarm   <= 1'b1;
          pin_decoy_trigger      <= 1'b1;
          pin_quantum_start      <= 1'b0;
          pin_physical_power_off <= 1'b0;
        end

        ST_LOCKDOWN: begin
          pin_non_threat_alarm   <= 1'b1;
          pin_decoy_trigger      <= 1'b1;
          pin_quantum_start      <= 1'b0;
          pin_physical_power_off <= 1'b1;
        end

        default: begin
          pin_non_threat_alarm   <= 1'b0;
          pin_decoy_trigger      <= 1'b0;
          pin_quantum_start      <= 1'b0;
          pin_physical_power_off <= 1'b0;
        end
      endcase
    end
  end

endmodule
