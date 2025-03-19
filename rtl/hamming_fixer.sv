module hamming_fixer (
	input  logic        clk,            // System clock
	input  logic        reset,          // System reset (asynchronous)
	input  logic        enable,         // Enable signal
	input  logic [3:0]  synd,           // Syndrome (4 bits)
	input  logic [11:0] bad_data,       // Encoded data with an error
	input logic [11:0] enc_data_old_in,   	// Encoded data to check
	
	input logic [7:0]  address_in,
	
	output logic [7:0] address_out,
	
	output logic [11:0] enc_data_old_out,   	// Encoded data to check
	
	output logic        fix_valid, 	// Indicates valid check (one cycle later)
	output logic [11:0] corrected_data  // Corrected 12-bit encoded data
);

// Internal signals
logic [11:0] error_pattern;  // Error correction pattern
logic [11:0] next_corrected_data;

// Decoder logic: converts syndrome (4 bits) to error pattern (12 bits)
always_comb begin
	error_pattern = 12'b0; // Default: no error correction
	case (synd)
		4'b0001: error_pattern = 12'b000000000001; // Error at bit 0
		4'b0010: error_pattern = 12'b000000000010; // Error at bit 1
		4'b0011: error_pattern = 12'b000000000100; // Error at bit 2
		4'b0100: error_pattern = 12'b000000001000; // Error at bit 3
		4'b0101: error_pattern = 12'b000000010000; // Error at bit 4
		4'b0110: error_pattern = 12'b000000100000; // Error at bit 5
		4'b0111: error_pattern = 12'b000001000000; // Error at bit 6
		4'b1000: error_pattern = 12'b000010000000; // Error at bit 7
		4'b1001: error_pattern = 12'b000100000000; // Error at bit 8
		4'b1010: error_pattern = 12'b001000000000; // Error at bit 9
		4'b1011: error_pattern = 12'b010000000000; // Error at bit 10
		4'b1100: error_pattern = 12'b100000000000; // Error at bit 11
		default: error_pattern = 12'b0;            // No error or unrecognized syndrome
	endcase
end

// XOR to fix the error and generate corrected data
always_comb begin
	next_corrected_data = bad_data ^ error_pattern;
end

// Sequential logic to store corrected data
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		corrected_data <= 12'b0;
		address_out <= 8'b0;
		fix_valid <= 1'b0;
		enc_data_old_out <= 12'b0;
	end else if (enable) begin
		corrected_data <= next_corrected_data;
		address_out <= address_in;
		fix_valid <= 1'b1;
		enc_data_old_out <= enc_data_old_in;
	end else begin
		corrected_data <= 12'b0;
		address_out <= 8'b0;
		fix_valid <= 1'b0;
		enc_data_old_out <= 12'b0;
		
	end
end

endmodule
