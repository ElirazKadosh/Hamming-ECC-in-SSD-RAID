module disk_reader (
	input logic        clk,           // System clock
	input logic        reset,         // System reset
	
	input logic out_valid_rd, //done reading going back to each sub block(depends on which block started the read process)
	
	input logic [11:0] D0_enc_in,		 // Encoded 12-bit data    
	input logic [11:0] D1_enc_in,    	 // Encoded 12-bit data
	input logic [11:0] P_in,			 // Parity
	
	input logic [11:0] normal_rd_valid_data_A, // from mem
	input logic [11:0] normal_rd_valid_data_B, // from mem
	input logic [7:0] normal_add,  			   // to mem
	input logic [1:0] normal_en_rd_mem,		   //to mem
	input logic normal_out_valid,			   // from controller
	
	input logic [11:0] write_rd_valid_data_A,// from mem
	input logic [11:0] write_rd_valid_data_B, // from mem
	input logic [7:0] write_add,   			   // to mem
	input logic [1:0] write_en_rd_mem,   			   // to mem
	input logic write_out_valid,			   // from parity calc (belongs to normal write)
	
	
	input logic [11:0] raid_rd_valid_data_A,    // from mem
	input logic [11:0] raid_rd_valid_data_B,    // from mem
	input logic [7:0] raid_add,   			    // to mem
	input logic [1:0] raid_en_rd_mem,  		    // to mem
	input logic raid_out_valid,			        // from controller
	
	output logic [11:0] D0_enc_out,		// Encoded 12-bit data
	output logic [11:0] D1_enc_out,		// Encoded 12-bit data
	output logic [11:0] P_out,			// Parity
	
	output logic 			normal_mem_valid, //mem has been written
	output logic 			write_mem_valid,   //mem has been written
	output logic 			raid_mem_valid,   //mem has been written
	
	output logic [11:0] rd_valid_data_A, // First read data block
	output logic [11:0] rd_valid_data_B, // Second read data block
	output logic		rd_valid,		
	output logic [7:0]  address,           // Address from which we will read
	output logic [1:0]  en_rd_mem      // Enable the read from the selected disks
);

logic normal_out_valid_d, write_out_valid_d, raid_out_valid_d;
logic write_out_valid_counter, normal_out_valid_counter, raid_out_valid_counter;


always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		rd_valid_data_A <= 12'b0;
		rd_valid_data_B <= 12'b0;
		rd_valid <= 1'b0;
		address <= 8'b0;
		en_rd_mem <= 2'b0;
		normal_mem_valid <= 1'b0;
		write_mem_valid <= 1'b0;
		raid_mem_valid <= 1'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		normal_out_valid_d <= 1'b0;
		write_out_valid_d <= 1'b0;
		raid_out_valid_d <= 1'b0;
		write_out_valid_counter <= 1'b0;
		normal_out_valid_counter <= 1'b0;
		raid_out_valid_counter <= 1'b0;
	end else if (normal_out_valid || write_out_valid || raid_out_valid) begin  // phase of reading from memory
		if(normal_out_valid) begin
			address <= normal_add;
			en_rd_mem <= normal_en_rd_mem;
			normal_out_valid_d <= 1'b1;
			normal_out_valid_counter <= 1'b1;  // Set counter for 2 additional cycles
		end else if (write_out_valid) begin
			address <= write_add;
			en_rd_mem <= write_en_rd_mem;
			write_out_valid_d <= 1'b1;
			write_out_valid_counter <= 1'b1;  // Set counter for 2 additional cycles
		end else if (raid_out_valid) begin
			address <= raid_add;
			en_rd_mem <= raid_en_rd_mem;
			raid_out_valid_d <= 1'b1;
			raid_out_valid_counter <= 1'b1;  // Set counter for 2 additional cycles
		end
		rd_valid <= 1'b1;
		D0_enc_out <= D0_enc_in;
		D1_enc_out <= D1_enc_in;
		P_out <= P_in;
	end else if (out_valid_rd) begin  //signaling to the block who asked for the read operation
		rd_valid <= 1'b0;
		D0_enc_out <= D0_enc_in;
		D1_enc_out <= D1_enc_in;
		P_out <= P_in;
		address <= normal_add | write_add | raid_add;
		if (normal_out_valid_d) begin
			rd_valid_data_A <= normal_rd_valid_data_A;
			rd_valid_data_B <= normal_rd_valid_data_B;
			normal_mem_valid<= 1'b1; 
		end
		if (write_out_valid_d) begin
			rd_valid_data_A <= write_rd_valid_data_A;
			rd_valid_data_B <= write_rd_valid_data_B;
			write_mem_valid<= 1'b1; 
		end
		if (raid_out_valid_d) begin
			rd_valid_data_A <= raid_rd_valid_data_A;
			rd_valid_data_B <= raid_rd_valid_data_B;
			raid_mem_valid<= 1'b1; 
		end
	end else begin
		normal_out_valid_d <= 1'b0;
		write_out_valid_d <= 1'b0;
		raid_out_valid_d <= 1'b0;
		normal_mem_valid <= 1'b0;
		write_mem_valid <= 1'b0;
		raid_mem_valid <= 1'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		address <= 8'b0;
		rd_valid_data_A <= 12'b0;
		rd_valid_data_B <= 12'b0;
		rd_valid <= 1'b0;
		en_rd_mem <= 2'b0;
		
		if (write_out_valid_counter != 1'b0) begin
			write_out_valid_counter <= 1'b0;
			write_out_valid_d <= 1'b1;
		end else begin
			write_out_valid_d <= 1'b0;
			write_mem_valid <= 1'b0;
		end
		if (normal_out_valid_counter != 1'b0) begin
			normal_out_valid_counter <= 1'b0;
			normal_out_valid_d <= 1'b1;
		end else begin
			normal_out_valid_d <= 1'b0;
			normal_mem_valid <= 1'b0;
		end
		if (raid_out_valid_counter != 1'b0) begin
			raid_out_valid_counter <= 1'b0;
			raid_out_valid_d <= 1'b1;
		end else begin
			raid_out_valid_d <= 1'b0;
			raid_mem_valid <= 1'b0;
		end
	end
	
end
endmodule