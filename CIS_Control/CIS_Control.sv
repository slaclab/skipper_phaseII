// CIS Control
//
// @aquinn 9/7/2023
//
// RTL block to implement waveforms for the CMOS Image Sensor control.
// All waveforms are triggered by the input trig signal.
// Maximum pattern length = 2^16
//

// Changelog:
// - Trigger becomes 'integration'. When active high, the CIS integrates signal
//   in the pinned photodiode. On the falling edge, the pattern is executed.

// Todo:
// - We need to separate integration and skipping, or we cannot skip > 10 sample.
//   Two issues with pattern-based approach: integration->skipping transition,
//   and RST
// - Replace skipping signal with NUM_SKIP_SAMPLES input register, max 10k skip
// - We need to signal FE/ADC when to sample baseline/value
// --> Add Phi1 and Phi2 to signal when we're sampling baseline and signal
// - Build a FSM with 3 patterns: CCD_Reset, Integration, Skipping
// -- Add CLK_DIV register to divide clock and duty-cycle to slow down this part


// Notes:
// Readout sequence is:
// 1) CCD reset (12 clk cycles)
// 2) Integration (Delayed by N clk cycles after integration)
// 3) Skipper readout (minimum 1 cycle)

//

module CIS_Control
  #(
  parameter     NUM_SIGNALS = 10,
  parameter     PATTERN_LEN = 12
  ) (
  input   logic 					                              clk,
  input   logic 					                              reset,
  input   logic [9:0]                                   clk_div,
  input   logic 					                              integration,
  input   logic [9:0]                                   skip_samples,
  input   logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_ccd_reset,
  input   logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_integration,
  input   logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_skipping,
  output  logic [(NUM_SIGNALS-1):0] 			              signal
  );


  // -----------------------------------------------------------------------------
  // --- Clock divider circuit
  // --- Generates a clk_div_en pulse every 'clk_div' clk cycles

  logic [9:0]  clk_div_cnt;
  logic        clk_div_en;

  always_ff @(posedge clk, posedge reset) begin
      if (reset) begin
        clk_div_cnt <= 1'b0;
        clk_div_en  <= 1'b0;
      end else begin
        if (clk_div_cnt == clk_div) begin
          clk_div_cnt  <= 8'b0;
          clk_div_en   <= 1'b1; // Generate a pulse when counter reaches clk_div
        end else begin
          clk_div_cnt  <= clk_div_cnt + 1'b1;
          clk_div_en   <= 1'b0;
        end
      end
  end

  // -----------------------------------------------------------------------------
  // --- FSM for PGP framing

  // FSM States
  typedef enum logic [2:0] { IDLE, CCD_RESET, INTEGRATION, SKIPPING } state_t;
  state_t state;

  logic last_inte;      //Value of trig last clk cycle.
  logic [15:0] 					counter;
  logic [15:0] 					counter_skipping;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] 	pattern_buffer;
  genvar i;

  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      state             <= IDLE;
      pattern_buffer    <= pattern_ccd_reset;
      counter           <= 0;
      last_inte         <= 1'b0;
      counter_skipping  <= 0;
    end else begin
      if (clk_div_en) begin
        case (state)
          IDLE: begin
            pattern_buffer <= pattern_ccd_reset;
            counter        <= PATTERN_LEN-1;
            if (integration) begin
              state          <= CCD_RESET;
            end else  begin
              state          <= IDLE;
            end
          end
          CCD_RESET: begin
            if (counter > 0) begin
              pattern_buffer    <= pattern_buffer << 1;
              counter           <= counter-1;
              state             <= CCD_RESET;
            end else begin
              pattern_buffer    <= pattern_integration;
              counter           <= PATTERN_LEN-1;
              state             <= INTEGRATION;
            end
          end
          INTEGRATION: begin
            if (counter > 0) begin
              pattern_buffer    <= pattern_buffer << 1;
              counter           <= counter-1;
              state             <= INTEGRATION;
            end else begin
              pattern_buffer    <= pattern_skipping;
              counter           <= PATTERN_LEN-1;
              state             <= SKIPPING;
              counter_skipping  <= skip_samples;
            end
          end
          SKIPPING: begin
            if (counter > 0) begin
              pattern_buffer    <= pattern_buffer << 1;
              counter           <= counter-1;
              state             <= SKIPPING;
            end else begin
              // Repeat pattern 'skip_samples' times
              if (counter_skipping > 0) begin
                pattern_buffer    <= pattern_skipping;
                counter           <= PATTERN_LEN-1;
                state             <= SKIPPING;
                counter_skipping  <= counter_skipping-1;
              end else begin
                // At the end of the sequence, return in ccd_reset state
                pattern_buffer    <= pattern_ccd_reset;
                counter           <= 0;
                state             <= IDLE;
                counter_skipping  <= 0;
              end
            end
          end
        endcase
      end // if (clk_div_en) begin
    end // if !(reset )
  end

  // Assign only signals from 1 to NUM_SIGNALS
  generate
    for(i = 0; i < NUM_SIGNALS; i++) begin
      assign signal[i] = pattern_buffer[i][PATTERN_LEN-1];
    end
  endgenerate

endmodule // CIS_Control
