//
// Independent Testbench for CIS_Control
//
// ***CHANGE BASIC PARAMETERS HERE:
//    NUM_SIGNALS = # of signals provided by CIS_Control
//    PATTERN_LEN = Length of the programmable patterns (in clock ticks)
//    TCLK_NS = Clock period in nanoseconds

module CIS_Control_tb #(
  parameter NUM_SIGNALS=8,
  parameter PATTERN_LEN=210,
  parameter TCLK_NS=1000
) ();

  logic 					clk;
  logic 					reset;
  logic 					integration;
  logic           skipping;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_data;
  logic [(NUM_SIGNALS-1):0] 			 signal;
  logic 					 running;

  // Map signals to CIS names
  logic CIS_PDrst, CIS_TG1, CIS_TG2, CIS_SG, CIS_OG, CIS_DG;

  assign CIS_PDrst  = signal[0];
  assign CIS_TG1    = signal[1];
  assign CIS_TG2    = signal[2];
  assign CIS_SG     = signal[3];
  assign CIS_OG     = signal[4];
  assign CIS_FG_RST = signal[5];
  assign CIS_DG     = signal[6];

  always #(TCLK_NS/2) clk <= !clk;

  CIS_Control #(NUM_SIGNALS,PATTERN_LEN) dut (.*);

  initial begin

    clk = 0;
    integration = 0;
    reset = 1;
    pattern_data = 0;

    // Note: Pattern here are read right to left, LSB is first
    // Tentatively organized as follows:
    // 10b    - End of integration time and transfer charge from PD to SG
    // 10x20b - Skipping operations (maximum 10)
    pattern_data[0] = {10'b11111_11111, {10{20'b11111_11111_11111_11111}}};  // CIS_TG1
    pattern_data[1] = {10'b10110_11111, {10{20'b00000_00000_00000_00000}}};  // CIS_TG2
    pattern_data[2] = {10'b10110_11111, {10{20'b00000_00000_00000_00000}}};  // CIS_SG
    pattern_data[3] = {10'b10110_11111, {10{20'b00000_00000_00000_00000}}};  // CIS_OG
    pattern_data[4] = {10'b10110_11111, {10{20'b00000_00000_00000_00000}}};  // CIS_FG_RST
    pattern_data[5] = {10'b10110_11111, {10{20'b00000_00000_00000_00000}}};  // CIS_DG
    pattern_data[6] = {10'b10110_11111, {10{20'b00000_00000_00000_00000}}};  // CIS_Rowselect
    pattern_data[7] = {10'b10110_11111, {10{20'b00000_00000_00000_00000}}};  // CIS_RowRst

    //Begin test...
    #100;
    reset = 0;
    #5000;
    integration = 1;

    //NOTE: MUST ENSURE THAT TRIGGER PULSE WIDTH IS >> ONE CLOCK PERIOD.
    #(50*TCLK_NS)
    integration = 0;
    #(TCLK_NS*PATTERN_LEN+TCLK_NS*10)

    $finish();

  end

  //Dump waveforms to a VCD file.
  initial begin
    $dumpfile("DB.vcd");
    $dumpvars(0,CIS_Control_tb);
  end

endmodule // CIS_Control_tb
