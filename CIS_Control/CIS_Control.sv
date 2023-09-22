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

// Questions:
// - We need to signal FE/ADC when to sample baseline/value
// - Where do we do CCD reset. At the beginning or at the end.


module CIS_Control
  #(
  parameter     NUM_SIGNALS = 10,
  parameter     PATTERN_LEN = 100
  ) (
  input   logic 					                              clk,
  input   logic 					                              reset,
  input   logic 					                              integration,
  input   logic                                         skipping,
  input   logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_data,
  output  logic [(NUM_SIGNALS-1):0] 			              signal,
  output  logic 					                              running
  );

  logic last_inte;      //Value of trig last clk cycle.
  logic [15:0] 					counter;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] 	pattern_buffer;
  genvar i;

  //The 0th entry in the pattern buffer is what is sent out over signal first.
  generate
    for(i = 0; i < NUM_SIGNALS; i++) begin
      always @(posedge clk, posedge reset) begin
        if(reset) begin
          running         <= 1'b0;
          pattern_buffer  <= 0;
          counter         <= 0;
          last_inte       <= 1'b0;
        end else begin
          last_inte <= integration;
          if(!running && !integration && last_inte) begin
            // If the block is not running and we see a trigger falling edge,
            // load the data and start running.
            running        <= 1'b1;
            pattern_buffer <= pattern_data;
            counter        <= PATTERN_LEN;
          end else if(running) begin
            //If the block is running, each pattern advances by 1 bit.
            if(counter > 0) begin
              pattern_buffer[i] <= {1'b0,pattern_buffer[i][(PATTERN_LEN-1):1]};
              counter <= counter-1;
            end
            else begin
              if (skipping) begin
                running <= 1'b1;
                pattern_buffer <= pattern_data;
                counter        <= PATTERN_LEN;
              end else begin
                running <= 1'b0;
              end
              //When counter == 0, stop running
            end
          end // if (running)
        end // else: !if(reset)
      end // always @ (posedge clk, posedge reset)
    end // for (i = 0; i < NUM_SIGNALS; i++)
  endgenerate

  // One signal needs to control the Photodiode RST
  // Here we assign signal[0] = PDrst
  // When PDrst = 0, charge is integrated in the pinned Photodiode

  assign signal[0] = (running) ? pattern_buffer[0][0] : ~(integration | last_inte);

  // Assign only signals from 1 to NUM_SIGNALS
  generate
    for(i = 1; i < NUM_SIGNALS; i++) begin
      assign signal[i] = pattern_buffer[i][0];
    end
  endgenerate



endmodule // CIS_Control
