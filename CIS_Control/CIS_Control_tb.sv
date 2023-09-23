//
// Independent Testbench for CIS_Control
//
// ***CHANGE BASIC PARAMETERS HERE:
//    NUM_SIGNALS = # of signals provided by CIS_Control
//    PATTERN_LEN = Length of the programmable patterns (in clock ticks)
//    TCLK_NS = Clock period in nanoseconds

module CIS_Control_tb #(
  parameter NUM_SIGNALS=8,
  parameter PATTERN_LEN=12,
  parameter TCLK_NS=1000,
  parameter SKIP_CYCLES=10,
  parameter CLK_DIVIDER=4
) ();

  logic 					clk;
  logic 					reset;
  logic 					integration;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_ccd_reset;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_integration;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_skipping;
  logic [(NUM_SIGNALS-1):0] 			 signal;
  logic 					 running;

  logic  [9:0]     clk_div = CLK_DIVIDER;
  logic  [9:0]     skip_samples = SKIP_CYCLES;

  // Map signals to CIS names
  logic CIS_PDrst, CIS_TG1, CIS_TG2, CIS_SG, CIS_OG, CIS_DG;

  assign CIS_PDrst  = signal[0];
  assign CIS_TG1    = signal[1];
  assign CIS_TG2    = signal[2];
  assign CIS_SG     = signal[3];
  assign CIS_OG     = signal[4];
  assign CIS_DG     = signal[5];
  assign CIS_FG_RST = signal[6];

  always #(TCLK_NS/2) clk <= !clk;

  CIS_Control #(NUM_SIGNALS,PATTERN_LEN) dut (.*);

  initial begin

    clk = 0;
    integration = 0;
    reset = 1;

    // Note: Pattern here are read right to left, LSB is first
    // Tentatively organized as follows:
    // 10x20b - Skipping operations (maximum 10)
    // 10b    - End of integration time and transfer charge from PD to SG

    pattern_ccd_reset[0]   = {12'b1111_1111_1111};  // CIS_PDrst
    pattern_ccd_reset[1]   = {12'b0000_0000_0000};  // CIS_TG1
    pattern_ccd_reset[2]   = {12'b0000_0000_0000};  // CIS_TG2
    pattern_ccd_reset[3]   = {12'b1111_1000_0000};  // CIS_SG
    pattern_ccd_reset[4]   = {12'b0011_1100_0000};  // CIS_OG
    pattern_ccd_reset[5]   = {12'b0000_1111_0000};  // CIS_DG
    pattern_ccd_reset[6]   = {12'b0000_0000_1111};  // CIS_FG_RST
    pattern_ccd_reset[7]   = {12'b1111_1111_1111};  // CIS_RowRst

    pattern_integration[0] = {12'b0000_0000_0000};  // CIS_PDrst
    pattern_integration[1] = {12'b0000_0011_0000};  // CIS_TG1
    pattern_integration[2] = {12'b0000_0001_1000};  // CIS_TG2
    pattern_integration[3] = {12'b0000_0000_1111};  // CIS_SG
    pattern_integration[4] = {12'b0000_0000_0000};  // CIS_OG
    pattern_integration[5] = {12'b0000_0000_0000};  // CIS_DG
    pattern_integration[6] = {12'b0000_0000_0000};  // CIS_FG_RST
    pattern_integration[7] = {12'b0000_0000_0000};  // CIS_RowRst

    pattern_skipping[0]    = {12'b0000_0000_0000};  // CIS_PDrst
    pattern_skipping[1]    = {12'b0000_0000_0000};  // CIS_TG1
    pattern_skipping[2]    = {12'b0000_0000_0000};  // CIS_TG2
    pattern_skipping[3]    = {12'b0000_0000_0000};  // CIS_SG
    pattern_skipping[4]    = {12'b0000_0000_0000};  // CIS_OG
    pattern_skipping[5]    = {12'b0000_0000_0000};  // CIS_DG
    pattern_skipping[6]    = {12'b0000_0000_0000};  // CIS_FG_RST
    pattern_skipping[7]    = {12'b0000_0000_0000};  // CIS_RowRst

    //Begin test
    #100;
    reset = 0;
    #5000;
    integration = 1;

    //NOTE: MUST ENSURE THAT TRIGGER PULSE WIDTH IS >> ONE CLOCK PERIOD.
    #(50*TCLK_NS)
    integration = 0;
    #(CLK_DIVIDER*(SKIP_CYCLES+10)*TCLK_NS*PATTERN_LEN+TCLK_NS*CLK_DIVIDER*100)
    $finish();
  end

  //Dump waveforms to a VCD file.
  initial begin
    $dumpfile("DB.vcd");
    $dumpvars(0,CIS_Control_tb);
  end

endmodule // CIS_Control_tb
