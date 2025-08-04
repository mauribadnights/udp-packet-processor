module top_module #(
  parameter DATA_WIDTH      = 8,
  parameter TARGET_MAC_ADDR = 48'h112233445566,
  parameter TARGET_IP_ADDR  = 32'hc0a80101,
  parameter TARGET_UDP_PORT = 16'd25044
) (
  input  wire                         clk,
  input  wire                         rst,

  // AXI-Stream Slave Interface (from MAC)
  input  wire [DATA_WIDTH-1:0]        s_axis_tdata,
  input  wire                         s_axis_tvalid,
  input  wire                         s_axis_tlast,
  output wire                         s_axis_tready,

  // AXI-Stream Master Interface
  output wire [DATA_WIDTH-1:0]        m_axis_tdata,
  output wire                         m_axis_tvalid,
  output wire                         m_axis_tlast,
  output wire [31:0]                  m_axis_tuser,
  input  wire                         m_axis_tready
);

  wire                                eth_to_ip_tready;
  wire [DATA_WIDTH-1:0]               eth_to_ip_tdata;
  wire                                eth_to_ip_tvalid;
  wire                                eth_to_ip_tlast;
  wire [17:0]                         eth_to_ip_tuser;

  wire                                ip_to_udp_tready;
  wire [DATA_WIDTH-1:0]               ip_to_udp_tdata;
  wire                                ip_to_udp_tvalid;
  wire                                ip_to_udp_tlast;
  wire [63:0]                         ip_to_udp_tuser;

  eth_parser #(
    .DATA_WIDTH(DATA_WIDTH),
    .TARGET_MAC_ADDR(TARGET_MAC_ADDR)
  ) eth_parser_1 (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tready(s_axis_tready),

    .m_axis_tdata(eth_to_ip_tdata),
    .m_axis_tvalid(eth_to_ip_tvalid),
    .m_axis_tlast(eth_to_ip_tlast),
    .m_axis_tuser(eth_to_ip_tuser),
    .m_axis_tready(eth_to_ip_tready)
  );

  ip_parser #(
    .DATA_WIDTH(DATA_WIDTH),
    .TARGET_IP_ADDR(TARGET_IP_ADDR)
  ) ip_parser_1 (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(eth_to_ip_tdata),
    .s_axis_tvalid(eth_to_ip_tvalid),
    .s_axis_tlast(eth_to_ip_tlast),
    .s_axis_tuser(eth_to_ip_tuser),
    .s_axis_tready(eth_to_ip_tready),

    .m_axis_tdata(ip_to_udp_tdata),
    .m_axis_tvalid(ip_to_udp_tvalid),
    .m_axis_tlast(ip_to_udp_tlast),
    .m_axis_tuser(ip_to_udp_tuser),
    .m_axis_tready(ip_to_udp_tready)
  );

  udp_parser #(
    .DATA_WIDTH(DATA_WIDTH),
    .TARGET_UDP_PORT(TARGET_UDP_PORT)
  ) udp_parser1 (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(ip_to_udp_tdata),
    .s_axis_tvalid(ip_to_udp_tvalid),
    .s_axis_tlast(ip_to_udp_tlast),
    .s_axis_tuser(ip_to_udp_tuser),
    .s_axis_tready(ip_to_udp_tready),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tuser(m_axis_tuser),
    .m_axis_tready(m_axis_tready)
  );

endmodule