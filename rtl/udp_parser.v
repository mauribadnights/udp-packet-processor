module udp_parser #(
  parameter DATA_WIDTH      = 8,
  parameter TARGET_UDP_PORT = 16'd25044
) (
  input  wire                         clk,
  input  wire                         rst,

  // AXI-Stream Slave Interface (from IP Parser)
  input  wire [DATA_WIDTH-1:0]        s_axis_tdata,
  input  wire                         s_axis_tvalid,
  input  wire                         s_axis_tlast,
  input  wire [63:0]                  s_axis_tuser,
  output wire                         s_axis_tready,

  // AXI-Stream Master Interface (to Application)
  output wire [DATA_WIDTH-1:0]        m_axis_tdata,
  output wire                         m_axis_tvalid,
  output wire                         m_axis_tlast,
  output wire [31:0]                  m_axis_tuser,
  input  wire                         m_axis_tready
);

  // DEFINE OUR STATES
  parameter S_IDLE = 3'd0; 
  parameter S_PARSE_HEADER = 3'd1;
  parameter S_STREAM_PAYLOAD = 3'd2;
  parameter S_DROP = 3'd3;
  parameter S_FINISH = 3'd4;

  // SOME OTHER PARAMETERS
  parameter HEADER_LEN = 4'd8;

  // DEFINE THE REGISTERS
  reg [2:0]            curr_state, next_state;
  reg [3:0]            byte_counter;
  reg [31:0]           ports;
  reg                  reset_counter;

  // SEQUENTIAL LOGIC
  always @(posedge clk) begin
    if (rst == 1'b1) begin
      curr_state <= S_IDLE;
      byte_counter <= 0;
      ports <= 0;
    end else begin
      curr_state <= next_state;
      if (s_axis_tvalid && (curr_state == S_PARSE_HEADER || (curr_state == S_IDLE && next_state == S_PARSE_HEADER))) begin
        byte_counter <= byte_counter + 1;
        if (byte_counter < 4) ports = {ports[23:0], s_axis_tdata};
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
          if (ports[15:0] != TARGET_UDP_PORT) begin
            next_state = S_DROP;
          end else begin
            next_state = S_STREAM_PAYLOAD;
          end
        end
      end
      S_STREAM_PAYLOAD: if (s_axis_tvalid && s_axis_tlast && m_axis_tready) next_state = S_FINISH;
      S_DROP: if (s_axis_tvalid && s_axis_tlast) next_state = S_IDLE;
      S_FINISH: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  wire valid_states = 
    (curr_state == S_STREAM_PAYLOAD) ||
    (curr_state == S_FINISH);
    
  assign reset_counter = (curr_state == S_IDLE) ? 1 : 0;

  // ASSIGN OUTPUT VALUES
  assign m_axis_tuser = ports;
  assign m_axis_tdata = s_axis_tdata;
  assign m_axis_tlast = valid_states && s_axis_tlast;
  assign m_axis_tvalid = valid_states && s_axis_tvalid;
  assign s_axis_tready = valid_states ? m_axis_tready : 1'b1;

endmodule