module eth_parser #(
  parameter DATA_WIDTH      = 8,
  parameter TARGET_MAC_ADDR = 48'h112233445566
) (
  input  wire                         clk,
  input  wire                         rst,

  // AXI-Stream Slave Interface (from MAC)
  input  wire [DATA_WIDTH-1:0]        s_axis_tdata,
  input  wire                         s_axis_tvalid,
  input  wire                         s_axis_tlast,
  output wire                         s_axis_tready,

  // AXI-Stream Master Interface (to IP Parser)
  output wire [DATA_WIDTH-1:0]        m_axis_tdata,
  output wire                         m_axis_tvalid,
  output wire                         m_axis_tlast,
  output wire [17:0]                  m_axis_tuser,
  input  wire                         m_axis_tready
);

  assign s_axis_tready = 1'b1; // Always ready to accept data for testbench purposes
endmodule