module write_for_read  (
	input logic             clk,      // System clock
	input logic             reset,    // System reset
	input logic [11:0]      corrected_data_D0,  // First encoded data from "Hamming fixer"            
	input logic [11:0]      corrected_data_D1,  // Second encoded data from "Hamming fixer"            
	input logic [7:0]       wr_add,   // Address to which we write the data  
	
	input logic [11:0]      enc_data_old_D0_in,   // Encoded data to check
	input logic [11:0]      enc_data_old_D1_in,   // Encoded data to check
	
	input logic             write_D0,  // from D0 fixer 
	input logic             write_D1,  // from D1 fixer 
	
	input logic             mem_valid, // from memory
	
	output logic [11:0]     enc_data_old_D0_out,  // Encoded data to check
	output logic [11:0]     enc_data_old_D1_out,  // Encoded data to check
	
	output logic            write_D0_out, // from D0 fixer 
	output logic            write_D1_out, // from D1 fixer 
	
	output logic [11:0]     corrected_data_D0_out,
	output logic [11:0]     corrected_data_D1_out,
	
	output logic [11:0]     wr_disk_0, // Data to write to the first disk
	output logic [11:0]     wr_disk_1, // Data to write to the second disk
	output logic [11:0]     wr_disk_2, // Data to write to the third disk
	output logic [2:0]      en_wr_mem, // Enable the write for the selected disks
	output logic            out_valid, // valid output to write
	
	output logic            out_mem_valid, // valid output after write
	
	output logic [7:0]      address    // Address to be written
	
);

logic [1:0] parity_disk;
always_comb begin
	parity_disk  = wr_add % 3;
end

// Counters to hold write_D0 and write_D1 for 4 extra cycles
logic [2:0] write_D0_count; // 3-bit counter (0-4)
logic [2:0] write_D1_count; // 3-bit counter (0-4)

// Process to store data and enable signals for 5 cycles
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		out_valid      <= 1'b0;
		wr_disk_0      <= 12'b0;
		wr_disk_1      <= 12'b0;
		wr_disk_2      <= 12'b0;
		en_wr_mem      <= 3'b0;
		address        <= 8'b0;
		out_mem_valid  <= 1'b0;
		
		enc_data_old_D0_out <= 12'b0;
		enc_data_old_D1_out <= 12'b0;
		write_D0_out   <= 1'b0;
		write_D1_out   <= 1'b0;
		write_D0_count <= 3'b000;
		write_D1_count <= 3'b000;
		corrected_data_D0_out <= 12'b0;
		corrected_data_D1_out <= 12'b0;
	end else begin
		// Capture input signals and start 4-cycle hold
		if (write_D0) begin
			write_D0_count <= 3'b100; // Start count at 4
			corrected_data_D0_out <= corrected_data_D0;
			enc_data_old_D0_out <= enc_data_old_D0_in;
			enc_data_old_D1_out <= enc_data_old_D1_in;
		end
		if (write_D1) begin
			write_D1_count <= 3'b100; // Start count at 4
			corrected_data_D1_out <= corrected_data_D1;
			enc_data_old_D0_out <= enc_data_old_D0_in;
			enc_data_old_D1_out <= enc_data_old_D1_in;
		end
		if (write_D0_count > 3'b0) begin
			write_D0_out   <= 1'b1;
			write_D0_count <= write_D0_count - 3'b1;
		end else begin
			write_D0_out   <= 1'b0;
		end
		if (write_D1_count > 3'b0) begin
			write_D1_out   <= 1'b1;
			write_D1_count <= write_D1_count - 3'b1;
		end else begin
			write_D1_out   <= 1'b0;
		end
		
		if(write_D0_count == 3'b0 && !write_D0) begin
			corrected_data_D0_out <= 12'b0;
		end
		if(write_D1_count == 3'b0 && !write_D1)	begin
			corrected_data_D1_out <= 12'b0;
		end
		if(write_D0_count == 3'b0 && !write_D0 && (write_D1_count == 3'b0 && !write_D1)) begin
			enc_data_old_D0_out <= 12'b0;
			enc_data_old_D1_out <= 12'b0;
		end
		
		// Normal operations
		if (write_D0 || write_D1) begin
			out_valid     <= 1'b1;
			address       <= wr_add;
			if (write_D0) begin
				if (parity_disk == 2'b00) begin
					en_wr_mem[1] <= 1'b1;
					wr_disk_1 <= corrected_data_D0;
				end else if (parity_disk == 2'b01 || parity_disk == 2'b10) begin
					en_wr_mem[0] <= 1'b1;
					wr_disk_0 <= corrected_data_D0;
				end
			end 
			if (write_D1) begin
				if (parity_disk == 2'b00 || parity_disk == 2'b01) begin
					en_wr_mem[2] <= 1'b1;
					wr_disk_2 <= corrected_data_D1;
				end else if (parity_disk == 2'b10) begin
					en_wr_mem[1] <= 1'b1;
					wr_disk_1 <= corrected_data_D1;
				end
			end    
		end else if (mem_valid) begin
			out_mem_valid        <= 1'b1;
		end else begin
			out_valid      <= 1'b0;
			wr_disk_0      <= 12'b0;
			wr_disk_1      <= 12'b0;
			wr_disk_2      <= 12'b0;
			en_wr_mem      <= 3'b0;
			address        <= 8'b0;
			out_mem_valid  <= 1'b0;
		end
	end
end
endmodule