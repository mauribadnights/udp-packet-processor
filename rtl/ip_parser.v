module ip_parser #(
  parameter DATA_WIDTH      = 8,
  parameter TARGET_IP_ADDR = 48'h112233445566
) (
  input  wire                         clk,
  input  wire                         rst,

  // AXI-Stream Slave Interface (from Eth Parser)
  input  wire [DATA_WIDTH-1:0]        s_axis_tdata,
  input  wire                         s_axis_tvalid,
  input  wire                         s_axis_tlast,
  input  wire [17:0]                  s_axis_tuser,
  output wire                         s_axis_tready,

  // AXI-Stream Master Interface (to UDP Parser)
  output wire [DATA_WIDTH-1:0]        m_axis_tdata,
  output wire                         m_axis_tvalid,
  output wire                         m_axis_tlast,
  output wire [63:0]                  m_axis_tuser,
  input  wire                         m_axis_tready
);

  // DEFINE OUR STATES
  parameter S_IDLE = 3'd0; 
  parameter S_PARSE_HEADER = 3'd1;
  parameter S_STREAM_PAYLOAD_FRAG = 3'd2;
  parameter S_STREAM_PAYLOAD_LAST = 3'd3;
  parameter S_DROP = 3'd4;
  parameter S_FINISH_FRAG = 3'd5;
  parameter S_FINISH_LAST = 3'd6;

  // SOME OTHER PARAMETERS
  parameter HEADER_LEN = 20;

  // DEFINE THE REGISTERS
  reg [2:0]            curr_state, next_state;
  reg [4:0]            byte_counter;
  reg                  mf;
  reg [7:0]            protocol;
  reg [63:0]           ips;
  reg                  reset_counter;

  // SEQUENTIAL LOGIC
  always @(posedge clk) begin
    if (rst == 1'b1) begin
      curr_state <= S_IDLE;
      byte_counter <= 0;
      mf <= 0;
      protocol <= 0;
      ips <= 0;
    end else begin
      curr_state <= next_state;
      if (s_axis_tvalid && (curr_state == S_PARSE_HEADER || (curr_state == S_IDLE && next_state == S_PARSE_HEADER))) begin
        byte_counter <= byte_counter + 1;
        if (byte_counter == 6) mf <= s_axis_tdata[5];
        if (byte_counter == 9) protocol <= s_axis_tdata;
        if (byte_counter > 11) ips <= {ips[55:0], s_axis_tdata};
      end else if (reset_counter) begin
        byte_counter <= 0;
      end
    end
  end

  always @(*) begin
    next_state = curr_state;
    case(curr_state)
      S_IDLE: if (s_axis_tvalid == 1'b1) next_state = S_PARSE_HEADER;
      S_PARSE_HEADER: begin
        if (byte_counter == HEADER_LEN-1) begin
          if (protocol != 17) begin
            next_state = S_DROP;
          end else begin
            if (mf == 1'b1) next_state = S_STREAM_PAYLOAD_FRAG;
            if (mf == 1'b0) next_state = S_STREAM_PAYLOAD_LAST;
          end
        end
      end
      S_STREAM_PAYLOAD_FRAG: if (s_axis_tvalid && s_axis_tlast && s_axis_tready) next_state = S_FINISH_FRAG;
      S_STREAM_PAYLOAD_LAST: if (s_axis_tvalid && s_axis_tlast && s_axis_tready) next_state = S_FINISH_LAST;
      S_DROP: if (s_axis_tvalid && s_axis_tlast && s_axis_tready) next_state = S_IDLE;
      S_FINISH_FRAG: next_state = S_IDLE;
      S_FINISH_LAST: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  wire valid_states = 
    (curr_state == S_STREAM_PAYLOAD_FRAG) || 
    (curr_state == S_STREAM_PAYLOAD_LAST) || 
    (curr_state == S_FINISH_FRAG) || 
    (curr_state == S_FINISH_LAST);

  assign reset_counter = (curr_state == S_IDLE) ? 1 : 0;

  // ASSIGN OUTPUT VALUES
  assign m_axis_tuser = ips;
  assign m_axis_tdata = s_axis_tdata;
  assign m_axis_tlast = (valid_states) && s_axis_tlast;
  assign m_axis_tvalid = valid_states && s_axis_tvalid;
  assign s_axis_tready = valid_states ? m_axis_tready : 1'b1;

endmodule