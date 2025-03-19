module memory #(
	parameter SIZE = 4  // Configurable memory size
) (
	input  logic         clk,           // System clock
	input  logic         reset,         // System reset (asynchronous)
	
	// Write inputs
	input  logic [11:0]  wr_disk0,      // Data to write to the first disk
	input  logic [11:0]  wr_disk1,      // Data to write to the second disk
	input  logic [11:0]  wr_disk2,      // Data to write to the third disk
	input  logic [2:0]   en_wr_mem,     // Enable the write for the selected disks
	input  logic [7:0]   address,       // Address to be written
	input  logic			wr_valid,		//valid writing to memory from disk_writer
	
	// Read inputs
	input  logic [1:0]   en_rd_mem,     // Enable the read from the selected disks
	input  logic [7:0]   add,           // Address from which we will read
	input  logic		 rd_valid,		//valid reading from memory
	
	input logic [11:0] D0_enc_in,		 // Encoded 12-bit data    
	input logic [11:0] D1_enc_in,    	 // Encoded 12-bit data
	input logic [11:0] P_in,			 // Parity
	
	input logic [2:0] disk_stat,		 // indicates which disks are still valid so we can use it to simulate a fall of one disks
	
	input logic [11:0] corrupted_data_D0,		//corrupted data going to memory
	input logic [11:0] corrupted_data_D1,		//corrupted data going to memory
	input logic [7:0] corrupted_address,	//the address to which we write the corrupted data
	input logic [1:0] disks_to_write,		//indicates which disks we going to write (00- none, 01- write D0, 10 - write D1, 11- write both)
	
	input logic [11:0] enc_data_old_D0_in,   	// Encoded data to check
	input logic [11:0] enc_data_old_D1_in,   	// Encoded data to check
	
	output logic zero_done,						// signal to read for raid that we finished zero the disk and can start recovery
	output logic [2:0] disk_stat_out,		 // indicates which disks are still valid so we can use it to simulate a fall of one disks

	
	output logic [11:0] enc_data_old_D0_out,   	// Encoded data to check
	output logic [11:0] enc_data_old_D1_out,   	// Encoded data to check
	
	output logic [11:0] D0_enc_out,		// Encoded 12-bit data
	output logic [11:0] D1_enc_out,		// Encoded 12-bit data
	output logic [11:0] P_out,			// Parity
	
	output logic [7:0]	out_address, 	//Output Address
	output logic		 out_valid_rd, 	//output done reading from memory
	output logic		 out_valid_wr, 	//output done writing to memory
	output logic [11:0]  out_rd_valid_A, // Output first read data block
	output logic [11:0]  out_rd_valid_B  // Output second read data block
);

// Define a memory array of size 3 * 256 (3 disks, 256 addresses per disk)
logic [11:0] memory [2:0][SIZE-1:0];
logic [1:0] parity_disk;
//logic mem_ready_rd;          // Internal flag to track the update
//logic mem_ready_wr;          // Internal flag to track the update

always_comb begin
	parity_disk = corrupted_address % 3;
end
// Writing to memory
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		// Reset all memory contents to 0
		integer i, j;
		for (i = 0; i < 3; i = i + 1) begin
			for (j = 0; j < SIZE; j = j + 1) begin
				memory[i][j] <= 12'b0;
			end
		end
		out_rd_valid_A <= 12'b0;
		out_rd_valid_B <= 12'b0;
		out_valid_rd <= 1'b0;
		//mem_ready_rd <= 1'b0;
		out_valid_wr <= 1'b0;
		//mem_ready_wr <= 1'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		out_address <= 8'b0;
		enc_data_old_D0_out <= 12'b0;
		enc_data_old_D1_out <= 12'b0;
		zero_done <= 1'b0;
	end else if(wr_valid || rd_valid) begin
		// Keep done signals high unless an operation is requested
		D0_enc_out <= D0_enc_in;
		D1_enc_out <= D1_enc_in;
		P_out <= P_in;
		enc_data_old_D0_out <= enc_data_old_D0_in;
		enc_data_old_D1_out <= enc_data_old_D1_in;
		// Writing operation
		if (en_wr_mem != 3'b000) begin
			if (en_wr_mem[0]) memory[0][address] <= wr_disk0; // Write to Disk 0
			if (en_wr_mem[1]) memory[1][address] <= wr_disk1; // Write to Disk 1
			if (en_wr_mem[2]) memory[2][address] <= wr_disk2; // Write to Disk 2
			//mem_ready_wr <= 1'b1;
			out_valid_wr <= 1'b1;
			out_address <= address;
		end
		
		// Reading operation
		if (en_rd_mem != 2'b00) begin
			//mem_ready_rd <= 1'b1;
			out_valid_rd <= 1'b1;
			out_address <= add;
			
			case (en_rd_mem)
				2'b01: begin
					out_rd_valid_A <= memory[0][add]; // Read from Disk 0
					out_rd_valid_B <= memory[1][add]; // Read from Disk 1
				end
				2'b10: begin
					out_rd_valid_A <= memory[0][add]; // Read from Disk 0
					out_rd_valid_B <= memory[2][add]; // Read from Disk 2
				end
				2'b11: begin
					out_rd_valid_A <= memory[1][add]; // Read from Disk 1
					out_rd_valid_B <= memory[2][add]; // Read from Disk 2
				end
				default: begin
					out_rd_valid_A <= 12'b0;
					out_rd_valid_B <= 12'b0;
				end
			endcase
		end
	end else if (disks_to_write != 2'b0) begin
		if(parity_disk == 2'b00) begin
			if(disks_to_write == 2'b01) begin
				memory[1][corrupted_address] <= corrupted_data_D0;
			end else if(disks_to_write == 2'b10) begin
				memory[2][corrupted_address] <= corrupted_data_D1;
			end else if(disks_to_write == 2'b11) begin
				memory[1][corrupted_address] <= corrupted_data_D0;
				memory[2][corrupted_address] <= corrupted_data_D1;
			end
		end else if(parity_disk == 2'b01) begin
			if(disks_to_write == 2'b01) begin
				memory[0][corrupted_address] <= corrupted_data_D0;
			end else if(disks_to_write == 2'b10) begin
				memory[2][corrupted_address] <= corrupted_data_D1;
			end else if(disks_to_write == 2'b11) begin
				memory[0][corrupted_address] <= corrupted_data_D0;
				memory[2][corrupted_address] <= corrupted_data_D1;
			end
		end if(parity_disk == 2'b10) begin
			if(disks_to_write == 2'b01) begin
				memory[0][corrupted_address] <= corrupted_data_D0;
			end else if(disks_to_write == 2'b10) begin
				memory[1][corrupted_address] <= corrupted_data_D1;
			end else if(disks_to_write == 2'b11) begin
				memory[0][corrupted_address] <= corrupted_data_D0;
				memory[1][corrupted_address] <= corrupted_data_D1;
			end
		end
	end else if (disk_stat != 3'b111) begin // we want to simulate a disk failure so we zero the corresponding disk
		integer j;
		if(disk_stat == 3'b110) begin
			for (j = 0; j < SIZE; j = j + 1) begin
				memory[0][j] <= 12'b0;
			end
		end else if (disk_stat == 3'b101) begin
			for (j = 0; j < SIZE; j = j + 1) begin
				memory[1][j] <= 12'b0;
			end
		end else if (disk_stat == 3'b011) begin
			for (j = 0; j < SIZE; j = j + 1) begin
				memory[2][j] <= 12'b0;
			end
		end
		disk_stat_out <= disk_stat;
		zero_done <= 1'b1;
	end else begin
		out_rd_valid_A <= 12'b0;
		out_rd_valid_B <= 12'b0;
		out_valid_rd <= 1'b0;
		out_valid_wr <= 1'b0;
		D0_enc_out <= 12'b0;
		D1_enc_out <= 12'b0;
		P_out <= 12'b0;
		out_address <= 8'b0;
		enc_data_old_D0_out <= 12'b0;
		enc_data_old_D1_out <= 12'b0;
		zero_done <= 1'b0;
		disk_stat_out <= 3'b0;
	end
end
endmodule