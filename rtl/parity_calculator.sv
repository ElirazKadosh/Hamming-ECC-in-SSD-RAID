module parity_calculator (
	input  logic        clk,         // System clock
	input  logic        reset,       // System reset (asynchronous)
	input  logic        enable,      // Enable signal
	input  logic [11:0] D0_enc_in,     // Data input to be encoded
	input  logic [11:0] D1_enc_in,     // Encoded 12-bit data
	input logic [7:0] address_in,
	output logic [7:0] address_out,
	output logic [11:0] P,// Parity
	output logic [11:0] D0_enc_out,
	output logic [11:0] D1_enc_out,

	output logic 		parity_data_valid
);
	// Internal signals
	logic [11:0] next_P; // Next state for enc_data

	// Combinational logic for parity bit calculation
	always_comb begin
		next_P = D0_enc_in ^ D1_enc_in;
	end

	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			parity_data_valid <= 1'b0;
			address_out <= 8'b0;
			D0_enc_out <= 12'b0;
			D1_enc_out <= 12'b0;
			P <= 12'b0;
		end else if (enable) begin
			parity_data_valid <= 1'b1;
			address_out <= address_in;
			D0_enc_out		  <= D0_enc_in;
			D1_enc_out 		  <= D1_enc_in;
			P 				  <= next_P;
		end else begin
			parity_data_valid <= 1'b0;
			address_out <= 8'b0;
			D0_enc_out <= 12'b0;
			D1_enc_out <= 12'b0;
			P <= 12'b0;
		end
	end

endmodule