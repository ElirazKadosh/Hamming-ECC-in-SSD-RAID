module hamming_encoder (
	input  logic        clk,         // System clock
	input  logic        reset,       // System reset (asynchronous)
	input  logic        enable,      // Enable signal
	input  logic [7:0]  data_in,     // Data input to be encoded
	input  logic [7:0]  address_in,  // Address
	
	output logic [11:0] enc_data,    // Encoded 12-bit data
	output  logic [7:0]  address_out,  // Address
	output logic        enc_data_valid // Indicates valid encoded data (one cycle later)
);

// Internal signals
logic P1, P2, P3, P4;          // Parity bits

// Combinational logic for parity bit calculation
always_comb begin
	P1 = data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4] ^ data_in[6];
	P2 = data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[5] ^ data_in[6];
	P3 = data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[7];
	P4 = data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7];
end

// Sequential logic for state update
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		enc_data       <= 12'b0;
		enc_data_valid <= 1'b0;
		address_out <= 8'b0;
	end else if (enable) begin
		address_out <= address_in;
		enc_data <= {data_in[7], data_in[6], data_in[5], data_in[4], P4, data_in[3], data_in[2], data_in[1], P3, data_in[0], P2, P1};    // Update encoded data
		enc_data_valid <= 1'b1;   // Assert valid one cycle later
	end else begin
		enc_data       <= 12'b0;
		enc_data_valid <= 1'b0;
		address_out <= 8'b0;
	end
end

endmodule