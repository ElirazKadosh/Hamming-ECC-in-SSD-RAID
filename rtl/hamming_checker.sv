
module hamming_checker (
	input logic        clk,         // System clock
	input logic        reset,       // System reset (asynchronous)     
	input logic [11:0] enc_data_old_in,   	// Encoded data to check
	input logic valid_normal_write,	// Enable signal from read_for_write
	input logic valid_normal_read,	// Enable signal from read_normal
	
	input logic [11:0] D0_enc_in,		 // Encoded 12-bit data    
	input logic [11:0] D1_enc_in,    	 // Encoded 12-bit data
	input logic [11:0] P_in,			 // Parity
	
	input logic [7:0]  address_in,
	
	output logic [7:0] address_out,
	
	output logic valid_normal_write_out,//  to decide where to go after check depends on read/write
	output logic valid_normal_read_out,	//  to decide where to go after check depends on read/write
	
	output logic [11:0] D0_enc_out,		// Encoded 12-bit data
	output logic [11:0] D1_enc_out,		// Encoded 12-bit data
	output logic [11:0] P_out,			// Parity
	output logic        check_valid, 	// Indicates valid check (one cycle later)
	
	output logic [11:0] enc_data_old_out,   	// Encoded data to check
	
	output logic [3:0] synd     // Syndrome pattern for error location . To write and read CTRL
);

// Internal signals
logic S1, S2, S3, S4; // syndrome bits
logic flag;
// Combinational logic for syndrome bit calculation
always_comb begin
	S1 = enc_data_old_in[0] ^ enc_data_old_in[2] ^ enc_data_old_in[4] ^ enc_data_old_in[6] ^ enc_data_old_in[8] ^ enc_data_old_in[10];
	S2 = enc_data_old_in[1] ^ enc_data_old_in[2] ^ enc_data_old_in[5] ^ enc_data_old_in[6] ^ enc_data_old_in[9] ^ enc_data_old_in[10];
	S3 = enc_data_old_in[3] ^ enc_data_old_in[4] ^ enc_data_old_in[5] ^ enc_data_old_in[6] ^ enc_data_old_in[11];
	S4 = enc_data_old_in[7] ^ enc_data_old_in[8] ^ enc_data_old_in[9] ^ enc_data_old_in[10] ^ enc_data_old_in[11];
end

// Sequential logic for state update
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		synd <= 4'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		enc_data_old_out <= 12'b0;
		check_valid <= 1'b0;
		address_out <= 8'b0;
		valid_normal_write_out <= 1'b0;
		valid_normal_read_out <= 1'b0;
		flag <= 1'b0;
	end else if (valid_normal_write || valid_normal_read) begin
		synd <= {S4, S3, S2, S1}; // Combine syndrome bits to form the next syndrome
		D0_enc_out <= D0_enc_in;
		D1_enc_out <= D1_enc_in;
		P_out <= P_in;
		enc_data_old_out <= enc_data_old_in;
		check_valid <= 1'b1;
		address_out <= address_in;
		valid_normal_write_out <= valid_normal_write;
		valid_normal_read_out <= valid_normal_read;
		flag <= 1'b1;
	end else if(flag) begin
		synd <= 4'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		check_valid <= 1'b0;
		address_out <= 8'b0;
		valid_normal_write_out <= 1'b0;
		valid_normal_read_out <= 1'b0;
		flag <= 1'b0;
	end	else begin
		synd <= 4'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		enc_data_old_out <= 12'b0;
		check_valid <= 1'b0;
		address_out <= 8'b0;
		valid_normal_write_out <= 1'b0;
		valid_normal_read_out <= 1'b0;
		flag <= 1'b0;
	end
end

endmodule