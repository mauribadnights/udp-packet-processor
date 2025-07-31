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

  // DEFINE OUR STATES
  parameter S_IDLE = 2'b00; 
  parameter S_PARSE_HEADER = 2'b01;
  parameter S_STREAM_PAYLOAD = 2'b10;
  parameter S_FINISH = 2'b11;

  // SOME OTHER PARAMETERS
  parameter HEADER_LEN = 14;
  parameter BROADCAST_MAC_ADDR = 48'hffffffffffff;

  // DEFINE THE REGISTERS
  reg [1:0]            curr_state, next_state;
  reg [3:0]            byte_counter;
  reg [111:0]          header;

  // SEQUENTIAL LOGIC
  always @(posedge clk) begin
    if (rst == 1'b1) begin
      curr_state <= S_IDLE;
      byte_counter <= 0;
      header <= 0;
    end else begin
      curr_state <= next_state;
      if (s_axis_tvalid && (curr_state == S_PARSE_HEADER || (curr_state == S_IDLE && next_state == S_PARSE_HEADER))) begin
        byte_counter <= byte_counter + 1;
        header[111:0] <= {header[111-DATA_WIDTH:0], s_axis_tdata};
      end else if (s_axis_tvalid == 1'b1 && curr_state == S_STREAM_PAYLOAD) begin
        byte_counter <= 0;
      end else byte_counter <= 0;
    end
  end
  
  // COMBINATIONAL BLOCK DETERMINING THE NEXT STATE
  always @(*) begin
    next_state = curr_state;
    case (curr_state)
      S_IDLE: if (s_axis_tvalid == 1'b1) next_state = S_PARSE_HEADER;
      S_PARSE_HEADER: if (byte_counter == HEADER_LEN-1) next_state = S_STREAM_PAYLOAD;
      S_STREAM_PAYLOAD: if (s_axis_tvalid && s_axis_tlast && s_axis_tready) next_state = S_FINISH
      S_FINISH: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  // ASSIGN OUTPUT VALUES
  assign m_axis_tuser[1:0] = (header[111:64] == TARGET_MAC_ADDR) ? 2'b01 : ((header[111:64] == BROADCAST_MAC_ADDR) ? 2'b10 : 2'b00);
  assign m_axis_tuser[17:2] = header[15:0];
  assign m_axis_tdata = s_axis_tdata;
  assign m_axis_tlast = s_axis_tlast;
  assign m_axis_tvalid = ((curr_state == S_STREAM_PAYLOAD) || (curr_state == S_FINISH)) && s_axis_tvalid;
  assign s_axis_tready = ((curr_state == S_STREAM_PAYLOAD) || (curr_state == S_FINISH)) ? m_axis_tready : 1'b1;

endmodule