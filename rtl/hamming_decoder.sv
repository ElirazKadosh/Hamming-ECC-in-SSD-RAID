module hamming_decoder (
	input  logic        clk,             // System clock
	input  logic        reset,           // System reset (asynchronous)
	input  logic [11:0] enc_data,        // Encoded data from "Hamming Checker" or from write for read (in case only D0 or D1 had to be fixed)
	input  logic [11:0] corrected_data,  // Corrected data from "Hamming Fixer"
	input logic sel_blk,
	input logic check_out_read_valid, // for enabling this module only when we are reading
	input logic wfr_to_decode_valid,
	input logic check_out_valid_D0,
	input logic check_out_valid_D1,
	input logic [3:0] check_out_synd_D0,
	input logic [3:0] check_out_synd_D1,
	
	output logic 		decode_valid,
	
	output logic [7:0]  dec_data         // Decoded 8-bit data
);

logic enable;
// Internal signals
logic [7:0] next_dec_data;
logic [11:0] selected_data;
// Combined combinational logic
always_comb begin
	enable = ((wfr_to_decode_valid) || (check_out_valid_D0 && check_out_valid_D1 && check_out_synd_D0 == 4'b0 && check_out_synd_D1 == 4'b0) && check_out_read_valid);
	// Select data source based on sel_blk
	
	selected_data = (sel_blk) ? corrected_data : enc_data;
	// Extract the 8 data bits from the selected 12-bit input
	next_dec_data = {selected_data[11], selected_data[10], selected_data[9],
			selected_data[8], selected_data[6], selected_data[5],
			selected_data[4], selected_data[2]};
	
end

// Sequential logic to store decoded data
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		dec_data <= 8'b0; // Reset decoded data to 0
		decode_valid <= 1'b0;
	end else if (enable) begin
		dec_data <= next_dec_data; // Update with new decoded data
		decode_valid <= 1'b1;
	end else begin
		dec_data <= 8'b0;
		decode_valid <= 1'b0;
	end
end

endmodule