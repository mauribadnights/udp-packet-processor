module top_module #(
  parameter DATA_WIDTH      = 8,
  parameter TARGET_MAC_ADDR = 48'h112233445566,
  parameter TARGET_IP_ADDR  = 32'hc0a80101
) (
  input  wire                         clk,
  input  wire                         rst,

  // AXI-Stream Slave Interface (from MAC)
  input  wire [DATA_WIDTH-1:0]        s_axis_tdata,
  input  wire                         s_axis_tvalid,
  input  wire                         s_axis_tlast,
  output wire                         s_axis_tready,

  // AXI-Stream Master Interface (to UDP Parser)
  output wire [DATA_WIDTH-1:0]        m_axis_tdata,
  output wire                         m_axis_tvalid,
  output wire                         m_axis_tlast,
  output wire [63:0]                  m_axis_tuser,
  input  wire                         m_axis_tready
);

  wire                                i_axis_tready;
  wire [DATA_WIDTH-1:0]               i_axis_tdata;
  wire                                i_axis_tvalid;
  wire                                i_axis_tlast;
  wire [17:0]                         i_axis_tuser;

  eth_parser #(
    .DATA_WIDTH(DATA_WIDTH),
    .TARGET_MAC_ADDR(TARGET_MAC_ADDR)
  ) eth_parser_1 (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tready(m_axis_tready),

    .s_axis_tready(i_axis_tready),
    .m_axis_tdata(i_axis_tdata),
    .m_axis_tvalid(i_axis_tvalid),
    .m_axis_tlast(i_axis_tlast),
    .m_axis_tuser(i_axis_tuser)
  );

  ip_parser #(
    .DATA_WIDTH(DATA_WIDTH),
    .TARGET_IP_ADDR(TARGET_IP_ADDR)
  ) ip_parser_1 (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(i_axis_tdata),
    .s_axis_tvalid(i_axis_tvalid),
    .s_axis_tlast(i_axis_tlast),
    .s_axis_tuser(i_axis_tuser),
    .s_axis_tready(s_axis_tready),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tuser(m_axis_tuser),
    .m_axis_tready(i_axis_tready)
  );

endmodule