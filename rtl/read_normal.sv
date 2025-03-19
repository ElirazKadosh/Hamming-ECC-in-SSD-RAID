module read_normal (
	input  logic        clk,           // System clock
	input  logic        reset,         // System reset
	
	input logic 		rd_valid,		// from user meaning we started a read request
	input logic [7:0]  rd_add,        // Address from which we will read
	
	input logic 		mem_valid,		//from memory
	input logic [11:0] in_rd_valid_data_A, // First read data block from memory
	input logic [11:0] in_rd_valid_data_B, // Second read data block from memory
	
	output logic [11:0] rd_valid_data_A, // First read data block
	output logic [11:0] rd_valid_data_B, // Second read data block
	output logic 		out_mem_valid,// this output after reading from mem
	
	output logic 		out_valid,
	output logic [7:0]  add,           // Address from which we will read
	output logic [1:0]  en_rd_mem      // Enable the read from the selected disks
);

logic [1:0] parity_disk;
logic read_normal_ready;          // Internal flag to track the update


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
		read_normal_ready <= 1'b0;
	end else if(rd_valid) begin
		read_normal_ready <= 1'b1;
		out_valid <= read_normal_ready;
	end else if (read_normal_ready) begin
		add <= rd_add;
		en_rd_mem <= ~parity_disk;
		read_normal_ready <= 1'b0;
		out_valid		<= 1'b1;
	end	else if (mem_valid) begin
		out_mem_valid <= 1'b0;
		rd_valid_data_A <= in_rd_valid_data_A;
		rd_valid_data_B <= in_rd_valid_data_B;
		out_mem_valid <= 1'b1;
		add <= rd_add;
	end else begin
		rd_valid_data_A <= 12'b0;
		rd_valid_data_B <= 12'b0;
		out_valid		<= 1'b0;
		out_mem_valid <= 1'b0;
		add   			<= 8'b0;
		en_rd_mem 		<= 2'b0;
		read_normal_ready <= 1'b0;
	end
end
endmodule