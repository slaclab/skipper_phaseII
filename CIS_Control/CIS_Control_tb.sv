//
// Independent Testbench for CIS_Control
//
// ***CHANGE BASIC PARAMETERS HERE:
//    NUM_SIGNALS = # of signals provided by CIS_Control
//    PATTERN_LEN = Length of the programmable patterns (in clock ticks)
//    TCLK_NS = Clock period in nanoseconds

module CIS_Control_tb #(
  parameter NUM_SIGNALS=9,
  parameter PIXEL_CLUSTER_SIZE=16,
  parameter PATTERN_LEN=12,
  parameter TCLK_NS=25,
  parameter SKIP_CYCLES=10,
  parameter CLK_DIVIDER=0
) ();

  logic 					clk;
  logic 					reset;
  logic 					integration;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_ccd_reset;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_integration;
  logic [(NUM_SIGNALS-1):0] [(PATTERN_LEN-1):0] pattern_skipping;
  logic 					 running;

  logic cis_PDrst;
  logic cis_TG1;
  logic cis_TG2;
  logic cis_SG;
  logic cis_OG;
  logic cis_DG;
  logic cis_FG_RST;
  logic cis_RowRst;
  logic cis_RowClk;
  logic sprocket_phi1;
  logic sprocket_phi2;
  logic sprocket_eoc;

  logic global_shutter = 1'b1;

  logic  [9:0]     clk_div = CLK_DIVIDER;
  logic  [9:0]     skip_samples = SKIP_CYCLES;

  always #(TCLK_NS/2) clk <= !clk;

  CIS_Control #(NUM_SIGNALS,PIXEL_CLUSTER_SIZE,PATTERN_LEN) dut (.*);

  initial begin

    clk = 0;
    integration = 0;
    reset = 1;
    sprocket_eoc = 0;

    // Note: Pattern here are read right to left, LSB is first
    // Tentatively organized as follows:
    // 10x20b - Skipping operations (maximum 10)
    // 10b    - End of integration time and transfer charge from PD to SG

    pattern_ccd_reset[0]    = {12'b1111_1111_1111};  // CIS_PDrst
    pattern_ccd_reset[1]    = {12'b0000_0000_0000};  // CIS_TG1
    pattern_ccd_reset[2]    = {12'b0000_0000_0000};  // CIS_TG2
    pattern_ccd_reset[3]    = {12'b1111_1000_0000};  // CIS_SG
    pattern_ccd_reset[4]    = {12'b0011_1100_0000};  // CIS_OG
    pattern_ccd_reset[5]    = {12'b0000_1111_0000};  // CIS_DG
    pattern_ccd_reset[6]    = {12'b0000_0000_1111};  // CIS_FG_RST
    pattern_ccd_reset[7]    = {12'b0000_0000_0000};  // SPROCKET_PED
    pattern_ccd_reset[8]    = {12'b0000_0000_0000};  // SPROCKET_SIG

    pattern_integration[0]  = {12'b0000_0000_0011};  // CIS_PDrst
    pattern_integration[1]  = {12'b0000_0011_0000};  // CIS_TG1
    pattern_integration[2]  = {12'b0000_0001_1000};  // CIS_TG2
    pattern_integration[3]  = {12'b0000_0000_1111};  // CIS_SG
    pattern_integration[4]  = {12'b0000_0000_0000};  // CIS_OG
    pattern_integration[5]  = {12'b0000_0000_0000};  // CIS_DG
    pattern_integration[6]  = {12'b0000_0000_0000};  // CIS_FG_RST
    pattern_integration[7]  = {12'b0000_0000_0000};  // SPROCKET_PED
    pattern_integration[8]  = {12'b0000_0000_0000};  // SPROCKET_SIG

    pattern_skipping[0]     = {12'b1111_1111_1111};  // CIS_PDrst
    pattern_skipping[1]     = {12'b0000_0000_0000};  // CIS_TG1
    pattern_skipping[2]     = {12'b0000_0000_0000};  // CIS_TG2
    pattern_skipping[3]     = {12'b1111_0000_0111};  // CIS_SG
    pattern_skipping[4]     = {12'b0011_1001_1100};  // CIS_OG
    pattern_skipping[5]     = {12'b0000_0000_0000};  // CIS_DG
    pattern_skipping[6]     = {12'b0000_0000_0000};  // CIS_FG_RST
    pattern_skipping[7]     = {12'b0100_0000_0000};  // SPROCKET_PED
    pattern_skipping[8]     = {12'b0000_0100_0000};  // SPROCKET_SIG

    //Begin test
    #(10*TCLK_NS);
    reset = 0;
    #(50*TCLK_NS);
    integration = 1;

    //NOTE: MUST ENSURE THAT TRIGGER PULSE WIDTH IS >> ONE CLOCK PERIOD.
    #(10*TCLK_NS)
    integration = 0;
    #((CLK_DIVIDER+1)*(SKIP_CYCLES+10)*PIXEL_CLUSTER_SIZE*TCLK_NS*PATTERN_LEN+TCLK_NS*(CLK_DIVIDER+1)*100)
    $finish();
  end

  //Dump waveforms to a VCD file.
  initial begin
    $dumpfile("DB.vcd");
    $dumpvars(0,CIS_Control_tb);
  end

  always #(TCLK_NS*200) sprocket_eoc <= !sprocket_eoc;


endmodule // CIS_Control_tb
