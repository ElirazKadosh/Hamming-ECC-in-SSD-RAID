module read_for_write (
	input  logic        clk,           	// System clock
	input  logic        reset,         	// System reset
	
	input logic 		rd_valid,		// from parity_calc
	input logic [7:0]  	rd_add,        	// Address from which we will read(from user)
	
	input logic [11:0] D0_enc_in,		 // Encoded 12-bit data    
	input logic [11:0] D1_enc_in,    	 // Encoded 12-bit data
	input logic [11:0] P_in,			 // Parity
	
	input logic 		mem_valid,		//from disk reader  (originally from memory)
	input logic [11:0]  in_rd_valid_data_A,// First read data block from memory
	input logic [11:0]  in_rd_valid_data_B,// Second read data block from memory
	
	output logic [11:0] D0_enc_out,		// Encoded 12-bit data
	output logic [11:0] D1_enc_out,		// Encoded 12-bit data
	output logic [11:0] P_out,			// Parity
	
	output logic [11:0] rd_valid_data_A, // First read data block
	output logic [11:0] rd_valid_data_B, // Second read data block
	output logic 		out_mem_valid, // this output after reading from mem
	
	output logic 		out_valid,
	output logic [7:0]  add,           	// Address from which we will read
	output logic [1:0]  en_rd_mem      // Enable the read from the selected disks
	
);

//logic read_done;

logic [1:0] parity_disk;

always_comb begin
	parity_disk = rd_add % 3;
end

always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		rd_valid_data_A <= 12'b0;
		rd_valid_data_B <= 12'b0;
		out_valid		<= 1'b0;
		out_mem_valid <= 1'b0;
		add   			<= 8'b0;
		en_rd_mem 		<= 2'b0;
		//read_done <= 1'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
	end else if(rd_valid) begin
		add <= rd_add;
		en_rd_mem <= ~parity_disk;
		out_valid <= 1'b1;
		D0_enc_out <= D0_enc_in;
		D1_enc_out <= D1_enc_in;
		P_out <= P_in;
	end else if (mem_valid) begin
		add <= rd_add;
		out_mem_valid <= 1'b1;
		rd_valid_data_A <= in_rd_valid_data_A;
		rd_valid_data_B <= in_rd_valid_data_B;
		D0_enc_out <= D0_enc_in;
		D1_enc_out <= D1_enc_in;
		P_out <= P_in;
	end else begin
		out_valid <= 1'b0;
		out_mem_valid <= 1'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		rd_valid_data_A <= 12'b0;
		rd_valid_data_B <= 12'b0;
		add   			<= 8'b0;
		en_rd_mem 		<= 2'b0;
		
	end
	
end
endmodule