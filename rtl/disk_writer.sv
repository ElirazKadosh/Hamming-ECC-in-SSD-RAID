module disk_writer (
	input logic 			clk,     // System clock
	input logic 			reset,   // System reset
	
	input logic out_valid_wr, //done writing going back to each sub block(depends on which block started the write proccess)
	
	input logic [11:0] enc_data_old_D0_in,   	// Encoded data to check
	input logic [11:0] enc_data_old_D1_in,   	// Encoded data to check
	
	// inputs from normal write
	input logic [11:0]		normal_wr_disk_0, 
	input logic [11:0]		normal_wr_disk_1, 
	input logic [11:0]		normal_wr_disk_2, 
	input logic [2:0]		normal_en_wr_mem,
	input logic [7:0]		normal_address,
	input logic 			normal_out_valid,
	
	// inputs from write for read
	input logic [11:0]		read_wr_disk_0, 
	input logic [11:0]		read_wr_disk_1, 
	input logic [11:0]		read_wr_disk_2, 
	input logic [2:0]		read_en_wr_mem,
	input logic [7:0]		read_address,
	input logic 			read_out_valid,
	
	// inputs from write for RAID
	input logic [11:0]		raid_wr_disk_0, 
	input logic [11:0]		raid_wr_disk_1, 
	input logic [11:0]		raid_wr_disk_2, 
	input logic [2:0]		raid_en_wr_mem,
	input logic [7:0]		raid_address,
	input logic 			raid_out_valid,
	
	output logic [11:0] enc_data_old_D0_out,   	// Encoded data to check
	output logic [11:0] enc_data_old_D1_out,   	// Encoded data to check
	
	
	
	output logic 			normal_mem_valid, //mem has been written
	output logic 			read_mem_valid,   //mem has been written
	output logic 			raid_mem_valid,   //mem has been written
	
	output logic [11:0]		wr_disk_0, // Data to write to the first disk
	output logic [11:0] 	wr_disk_1, // Data to write to the second disk
	output logic [11:0] 	wr_disk_2, // Data to write to the third disk
	output logic [2:0] 		en_wr_mem, // Enable the write for the selected disks
	output logic [7:0] 		address,// Address to be written
	output logic 			wr_valid
);


logic normal_out_valid_d, read_out_valid_d, raid_out_valid_d;
logic normal_out_valid_counter, read_out_valid_counter, raid_out_valid_counter;

always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		wr_disk_0 <= 12'b0;
		wr_disk_1 <= 12'b0;
		wr_disk_2 <= 12'b0;
		en_wr_mem <= 3'b0;
		address <= 8'b0;
		wr_valid <= 1'b0;
		normal_mem_valid <= 1'b0;
		read_mem_valid <= 1'b0;
		raid_mem_valid <= 1'b0;
		normal_out_valid_d <= 1'b0;
		read_out_valid_d <= 1'b0;
		raid_out_valid_d <= 1'b0;
		normal_out_valid_counter <= 1'b0;
		read_out_valid_counter <= 1'b0;
		raid_out_valid_counter <= 1'b0;
		enc_data_old_D0_out <= 12'b0;
		enc_data_old_D1_out <= 12'b0;
	end else if (normal_out_valid || read_out_valid || raid_out_valid) begin  // phase of writing to memory
		if(normal_out_valid) begin
			wr_disk_0 <= normal_wr_disk_0;
			wr_disk_1 <= normal_wr_disk_1;
			wr_disk_2 <= normal_wr_disk_2;
			en_wr_mem <= normal_en_wr_mem;
			address <= normal_address;
			normal_out_valid_d <= 1'b1;
			normal_out_valid_counter <= 1'b1;
			wr_valid <= 1'b1;
		end else if (read_out_valid) begin
			wr_disk_0 <= read_wr_disk_0;
			wr_disk_1 <= read_wr_disk_1;
			wr_disk_2 <= read_wr_disk_2;
			en_wr_mem <= read_en_wr_mem;
			address <= read_address;
			read_out_valid_d <= 1'b1;
			read_out_valid_counter <= 1'b1;
			wr_valid <= 1'b1;
		end else if (raid_out_valid) begin
			wr_disk_0 <= raid_wr_disk_0;
			wr_disk_1 <= raid_wr_disk_1;
			wr_disk_2 <= raid_wr_disk_2;
			en_wr_mem <= raid_en_wr_mem;
			address <= raid_address;
			raid_out_valid_d <= 1'b1;
			raid_out_valid_counter <= 1'b1;
			wr_valid <= 1'b1;
		end
		enc_data_old_D0_out <= enc_data_old_D0_in;
		enc_data_old_D1_out <= enc_data_old_D1_in;
		//wr_valid <= 1'b1;
	end else if (out_valid_wr) begin  //signaling to the block who asked for the write operation
		wr_valid <= 1'b0;
		address <= normal_address | read_address | raid_address;
		enc_data_old_D0_out <= enc_data_old_D0_in;
		enc_data_old_D1_out <= enc_data_old_D1_in;
		if (normal_out_valid_d) begin
			normal_mem_valid<= 1'b1; 
		end
		if (read_out_valid_d) begin
			read_mem_valid<= 1'b1; 
		end
		if (raid_out_valid_d) begin
			raid_mem_valid<= 1'b1; 
		end
		
	end else begin
		
		wr_disk_0 <= 12'b0;
		wr_disk_1 <= 12'b0;
		wr_disk_2 <= 12'b0;
		en_wr_mem <= 3'b0;
		address <= 8'b0;
		wr_valid <= 1'b0;		
		normal_mem_valid <= 1'b0;
		read_mem_valid <= 1'b0;
		raid_mem_valid <= 1'b0;
		normal_out_valid_d <= 1'b0;
		read_out_valid_d <= 1'b0;
		raid_out_valid_d <= 1'b0;
		enc_data_old_D0_out <= 12'b0;
		enc_data_old_D1_out <= 12'b0;
		if (read_out_valid_counter != 1'b0) begin
			read_out_valid_counter <= 1'b0;
			read_out_valid_d <= 1'b1;
		end else begin
			read_out_valid_d <= 1'b0;
			read_mem_valid <= 1'b0;
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