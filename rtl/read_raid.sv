module read_raid (
	input  logic        clk,           // System clock
	input  logic        reset,         // System reset
	
	input logic 		enable,		// from memory after zero
	input logic [2:0]	disk_stat,	//from memory
	
	input logic 		mem_valid,		//from memory after reading
	input logic [11:0] in_rd_valid_data_A, // First read data block from memory
	input logic [11:0] in_rd_valid_data_B, // Second read data block from memory
	
	input logic 		write_done,		//from write raid saying we finished the current write lets move to next one
	
	output logic [11:0] rd_valid_data_A, // First read data block
	output logic [11:0] rd_valid_data_B, // Second read data block
	output logic 		out_mem_valid,// this output after reading from mem
	
	output logic 		last_op,
	output logic [2:0]	disk_stat_out,	//to write raid

	
	output logic 		out_valid,
	output logic [7:0]  add,           // Address from which we will read
	output logic [1:0]  en_rd_mem      // Enable the read from the selected disks
);

logic [7:0] address;
logic [2:0] disks_to_read;

always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		rd_valid_data_A <= 12'b0;
		rd_valid_data_B <= 12'b0;
		out_valid		<= 1'b0;
		out_mem_valid <= 1'b0;
		add   			<= 8'b0;
		en_rd_mem 		<= 2'b0;
		address <= 8'b0;
		disks_to_read <= 3'b0;
		last_op <= 1'b0;
		disk_stat_out <= 3'b0;
	end else if(enable) begin
		add <= 8'b0;
		disks_to_read <= disk_stat;
		disk_stat_out <= disk_stat;
		out_valid <= 1'b1;
		if(disk_stat == 3'b110) begin
			en_rd_mem <= 2'b11;
		end else if(disk_stat == 3'b101) begin
			en_rd_mem <= 2'b10;
		end else if(disk_stat == 3'b011) begin
			en_rd_mem <= 2'b01;
		end
		address <= address + 8'b1;
	end else if (write_done) begin 
		add <= address;
		out_valid <= 1'b1;
		disk_stat_out <= disks_to_read;
		if(disks_to_read == 3'b110) begin
			en_rd_mem <= 2'b11;
		end else if(disks_to_read == 3'b101) begin
			en_rd_mem <= 2'b10;
		end else if(disks_to_read == 3'b011) begin
			en_rd_mem <= 2'b01;
		end
		if (address == 8'd3) begin
			address <= 8'b0;
			last_op <= 1'b1;
			disks_to_read <= 3'b0;
		end else begin
			address <= address + 8'b1;
			last_op <= 1'b0;
		end
	end else if (mem_valid) begin
		rd_valid_data_A <= in_rd_valid_data_A;
		rd_valid_data_B <= in_rd_valid_data_B;
		add <= address;
		out_mem_valid <= 1'b1;
	end else begin		
		rd_valid_data_A <= 12'b0;
		rd_valid_data_B <= 12'b0;
		out_valid		<= 1'b0;
		out_mem_valid <= 1'b0;
		add   			<= 8'b0;
		en_rd_mem 		<= 2'b0;
		last_op <= 1'b0;
	end
	
end

endmodule