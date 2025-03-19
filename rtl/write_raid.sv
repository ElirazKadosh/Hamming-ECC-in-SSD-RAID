module write_raid (
	input logic 			clk, 	 // System clock
	input logic 			reset,   // System reset
	input logic				enable,//from read raid

	input logic [11:0]		raid_data, // Recovered data from "RAID5 Recovery"
	input logic [2:0]		disk_stat, //from read raid
	input logic 			mem_valid,//from memory
	
	input last_op,				//from read raid indicating we going to do last opreation
	
	output logic [11:0]		wr_disk_0, // Data to write to the first disk
	output logic [11:0] 	wr_disk_1, // Data to write to the second disk
	output logic [11:0] 	wr_disk_2, // Data to write to the third disk
	output logic [2:0] 		en_wr_mem, // Enable the write for the selected disks
	output logic 			out_valid, // valid output
	
	output logic 			out_mem_valid, // valid output after write
	
	output logic			done_recovery, //signal to ctrl indicating we finished recovery of the disk
	
	output logic [7:0] 		address    // Address to be written
	
);

logic [7:0] address_counter;

// Registers for D-FF outputs
logic [11:0]  reg_wr_disk_0;
logic [11:0]  reg_wr_disk_1;
logic [11:0]  reg_wr_disk_2;
logic [2:0]   reg_en_wr_mem;

logic last_op_ready;
always_comb begin
	reg_wr_disk_0 = 12'b0;
	reg_wr_disk_1 = 12'b0;
	reg_wr_disk_2 = 12'b0;
	reg_en_wr_mem = 3'b0;
	if (disk_stat == 3'b011) begin
		reg_wr_disk_0 = raid_data;
		reg_en_wr_mem = 3'b001;
	end else if (disk_stat == 3'b101) begin
		reg_wr_disk_1 = raid_data;
		reg_en_wr_mem = 3'b010;
	end else if (disk_stat == 3'b110) begin
		reg_wr_disk_2 = raid_data;
		reg_en_wr_mem = 3'b100;
	end
	
end

always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		wr_disk_0 <= 12'b0;
		wr_disk_1 <= 12'b0;
		wr_disk_2 <= 12'b0;
		en_wr_mem <= 3'b0;
		address   <= 8'b0;
		out_valid <= 1'b0;
		out_mem_valid <= 1'b0;
		done_recovery <= 1'b0;
		last_op_ready <= 1'b0;
		address_counter <= 8'b0;
	end else if(enable) begin
		wr_disk_0 <= reg_wr_disk_0;
		wr_disk_1 <= reg_wr_disk_1;
		wr_disk_2 <= reg_wr_disk_2;
		en_wr_mem <= reg_en_wr_mem;
		address   <= address_counter;
		out_valid <= 1'b1;
		if (address_counter == 8'd3) begin
			address_counter <= 8'b0;
		end else begin
			address_counter <= address_counter + 8'b1;
		end
	end else if (mem_valid) begin
		if(last_op_ready) begin
			done_recovery <= 1'b1;
			out_valid <= 1'b0;
			out_mem_valid <= 1'b0;
			last_op_ready <= 1'b0;
		end else begin
			out_valid <= 1'b0;
			out_mem_valid <= 1'b1;
		end
	end else if (last_op) begin
		last_op_ready <= last_op;
	end
	else begin
		wr_disk_0 <= 12'b0;
		wr_disk_1 <= 12'b0;
		wr_disk_2 <= 12'b0;
		en_wr_mem <= 3'b0;
		address   <= 8'b0;
		out_valid <= 1'b0;
		out_mem_valid <= 1'b0;
		done_recovery <= 1'b0;
	end
	
end
endmodule