module compare_encoded_blocks (
	input  logic        clk,         // System clock
	input  logic        reset,       // System reset (asynchronous)
	input  logic        enable,      // Enable signal from write CTRL (based on synd D0 and D1)
	input  logic [11:0] enc_data,      // Encoded block from "Hamming Encoder"
	input  logic [11:0] enc_data_old,  // Encoded block from "Disk Reader"
	
	input logic [11:0] D0_enc_in,		 // Encoded 12-bit data    
	input logic [11:0] D1_enc_in,    	 // Encoded 12-bit data
	input logic [11:0] P_in,			 // Parity
	
	input logic [7:0]  address_in,
	
	output logic [7:0] address_out,
	
	output logic [11:0] D0_enc_out,		// Encoded 12-bit data
	output logic [11:0] D1_enc_out,		// Encoded 12-bit data
	output logic [11:0] P_out,			// Parity
	
	output logic        compare_valid, 	// Indicates valid check for compare (one cycle later)
	
	output logic        equal        // Indicates whether the two blocks are equal
);

// Internal signals
logic [11:0] xor_result; // XOR result for each pair of bits
logic         nor_result; // Result of NOR operation across all XOR results


always_comb begin
	xor_result = enc_data ^ enc_data_old; // Perform bitwise XOR
	nor_result = ~(|xor_result); // NOR of all XOR results
end

// Sequential logic to store the final result in equal
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		equal <= 1'b0; // Reset equal to 0
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		compare_valid <= 1'b0;
		address_out <= 8'b0;
	end else if (enable) begin
		equal <= nor_result; // Update equal based on nor_result
		D0_enc_out <= D0_enc_in;
		D1_enc_out <= D1_enc_in;
		P_out <= P_in;
		compare_valid <= 1'b1;
		address_out <= address_in;
	end else begin
		equal <= 1'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		compare_valid <= 1'b0;
		address_out <= 8'b0;
	end
end

endmodule