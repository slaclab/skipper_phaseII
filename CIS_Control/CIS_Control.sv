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
// - Separate integration and skipping, or we cannot skip > 10 sample.
//   Two issues with pattern-based approach: integration->skipping transition,
//   and RST. Implemented three different pattern sequences, controlled by a FSM.
// - Replaced skipping signal with NUM_SKIP_SAMPLES input register, max 10k skip
// - Extended patterns to 10 to signal FE/ADC when to sample baseline/value
// - Added CLK_DIV register to divide clock and duty-cycle to slow down this part
// - Added global_shutter mode
// - Ports are now named in CIS_Control

// Notes:
// Readout sequence is:
// 1) CCD reset (12 clk cycles)
// 2) Integration (Delayed by N clk cycles after integration)
// 3) Skipper readout (minimum 1 cycle)

// Important:
// - CIS_RowRst (pattern[7] in test-bench) needs to be reset at least once
//   Connect it to reset at top level?
// - Patterns are executed from MSB to LSB (easier to write/read left->right)

module CIS_Control
  #(
  parameter     NUM_SIGNALS         = 9,
  parameter     PIXEL_CLUSTER_SIZE  = 16,
  parameter     PATTERN_LEN         = 12
  ) (
  input   logic 					                              clk,
  input   logic 					                              reset,
  input   logic [9:0]                                   clk_div,
  input   logic                                         global_shutter,
  input   logic 					                              integration,
  input   logic [15:0]                                  skip_samples,
  input   logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_ccd_reset,
  input   logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_integration,
  input   logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_skipping,
  // Outputs to CIS pixel
  output  logic                                         cis_PDrst,
  output  logic                                         cis_TG1,
  output  logic                                         cis_TG2,
  output  logic                                         cis_SG,
  output  logic                                         cis_DG,
  output  logic                                         cis_OG,
  output  logic                                         cis_FG_RST,
  // Outputs to CIS pixel selection logic
  output  logic                                         cis_RowRst,
  output  logic                                         cis_RowClk,
  // Outputs to SPROCKET
  output  logic                                         sprocket_phi1,
  output  logic                                         sprocket_phi2
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

  logic [3:0] 					counter_pixel;

  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] 	pattern_buffer;
  genvar i;

  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      cis_RowRst        <= 1'b1;
      counter_pixel     <= 4'd0;
      cis_RowClk        <= 1'b0;
      state             <= IDLE;
      pattern_buffer    <= pattern_ccd_reset;
      counter           <= 0;
      last_inte         <= 1'b0;
      counter_skipping  <= 0;
    end else begin
      if (clk_div_en) begin
        case (state)
          IDLE: begin
            cis_RowClk     <= 1'b0;
            cis_RowRst     <= 1'b0;
            counter_pixel  <= 4'd0;
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
              pattern_buffer    <= pattern_buffer >> 1;
              counter           <= counter-1;
              state             <= CCD_RESET;
            end else begin
              pattern_buffer    <= pattern_integration;
              counter           <= PATTERN_LEN-1;
              state             <= INTEGRATION;
            end
          end
          INTEGRATION: begin
            // If integration is high, do nothing
            if (integration) begin
              pattern_buffer    <= pattern_buffer;
              counter           <= counter;
              state             <= INTEGRATION;
            // When integration goes low, start the counting process
            end else if (counter > 0) begin
              pattern_buffer    <= pattern_buffer >> 1;
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
            // Here we are doing the SKIPPING
            if (counter > 0) begin
              pattern_buffer    <= pattern_buffer >> 1;
              counter           <= counter-1;
              state             <= SKIPPING;
            end else begin
              // Repeat pattern 'skip_samples' times
			        // when counter_skipping = 1, it's the last cycle.
              if (counter_skipping > 1) begin
                pattern_buffer    <= pattern_skipping;
                counter           <= PATTERN_LEN-1;
                state             <= SKIPPING;
                counter_skipping  <= counter_skipping-1;
                cis_RowClk        <= 1'b0;
				//Set this up to be ready for the next transition.
				last_inte         <= 1'b0;
              end else begin
                // If global_shutter mode is enabled, we repeat skipping sequence
                // only, without going through integration and CCD reset
                if (global_shutter && (counter_pixel < (PIXEL_CLUSTER_SIZE-1))) begin
                  // We wait for End of Conversion in SPROCKET
                  if (!integration && last_inte) begin
                    counter_pixel     <= counter_pixel + 1;
                    pattern_buffer    <= pattern_skipping;
                    counter           <= PATTERN_LEN-1;
                    state             <= SKIPPING;
                    counter_skipping  <= skip_samples;
                    cis_RowClk        <= 1'b1;
                  end else begin // otherwise just keep current state
                    counter_pixel     <= counter_pixel;
                    pattern_buffer    <= pattern_buffer;
                    counter           <= counter;
                    state             <= state;
                    counter_skipping  <= counter_skipping;
                    cis_RowClk        <= cis_RowClk;
					last_inte         <= integration;
                  end
                end else begin
                  // At the end of the sequence, return in ccd_reset state
                  pattern_buffer    <= pattern_ccd_reset;
                  counter           <= 0;
                  state             <= IDLE;
                  counter_skipping  <= 0;
                  cis_RowClk        <= 1'b1;
                end
              end
            end
          end
        endcase
      end // if (clk_div_en) begin
    end // if !(reset )
  end

  assign cis_PDrst    = pattern_buffer[0][0];
  assign cis_TG1      = pattern_buffer[1][0];
  assign cis_TG2      = pattern_buffer[2][0];
  assign cis_SG       = pattern_buffer[3][0];
  assign cis_OG       = pattern_buffer[4][0];
  assign cis_DG       = pattern_buffer[5][0];
  assign cis_FG_RST   = pattern_buffer[6][0];
  assign sprocket_phi1 = pattern_buffer[7][0];
  assign sprocket_phi2 = pattern_buffer[8][0];



endmodule // CIS_Control
