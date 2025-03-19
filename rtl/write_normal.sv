module write_normal (
	input logic 			clk, 	 // System clock
	input logic 			reset,   // System reset
	input logic 			enable,  //check or compare are done so we can write normal now
	input logic [11:0]		P,		 // Parity block														
	input logic [11:0]		D0_enc,  // First encoded data from "Hamming Encoding"			
	input logic [11:0]		D1_enc,  // Second encoded data from "Hamming Encoding"			
	input logic [7:0]		wr_add,  // Address to which we write the data                     
	input logic 			mem_valid,//from memory
	
	input logic [3:0] 		synd_D0,  // Syndrome pattern for error location
	input logic [3:0] 		synd_D1,  // Syndrome pattern for error location
	input logic       		equal_D0, // Indicates whether the two blocks are equal
	input logic       		equal_D1, // Indicates whether the two blocks are equal
	
	output logic [11:0]		wr_disk_0, // Data to write to the first disk
	output logic [11:0] 	wr_disk_1, // Data to write to the second disk
	output logic [11:0] 	wr_disk_2, // Data to write to the third disk
	output logic [2:0] 		en_wr_mem, // Enable the write for the selected disks
	output logic 			out_valid, // valid output before write
	
	output logic 			out_mem_valid, // Valid output after write going to CTRL to indicate finished write normal operation
	
	output logic [7:0] 		address    // Address to be written
);

logic [1:0] data_wfw;

typedef enum logic [2:0] {WR_DISK0 = 3'b001, WR_DISK1 = 3'b010, WR_DISK2 = 3'b100, WR_DISK0_DISK1 = 3'b011, WR_DISK0_DISK2 = 3'b101, WR_DISK1_DISK2 = 3'b110, WR_ALL = 3'b111} write_t;

// Registers for D-FF outputs
logic [11:0]  reg_wr_disk_0;
logic [11:0]  reg_wr_disk_1;
logic [11:0]  reg_wr_disk_2;
logic [2:0]   reg_en_wr_mem;
logic [1:0]   parity_disk;

logic [11:0]  P0_block;
logic [11:0]  D0_block;
logic [11:0]  D1_block;

always_comb begin
	data_wfw = 2'b00;
	// we write P everytime we write one of D0 or D1(including both)
	if((synd_D0!= 4'b0) && (synd_D1 != 4'b0)) begin // both with error, need to write both
		data_wfw = 2'b11;
	end else if ((synd_D0 == 4'b0) && (synd_D1 != 4'b0)) begin // only D1 with error, writing D1 
		if(equal_D0) begin
			data_wfw = 2'b10; // only write D1
		end else begin
			data_wfw = 2'b11; // D0 is diff so also write it too
		end
	end else if ((synd_D0 != 4'b0) && (synd_D1 == 4'b0)) begin // only D0 with error, writing D0 
		if(equal_D0) begin
			data_wfw = 2'b01; // only write D0
		end else begin
			data_wfw = 2'b11; // D1 is diff so also write it too
		end
	end else if ((synd_D0 == 4'b0) && (synd_D1 == 4'b0)) begin // both without errors, writing based on equals or not for each
		if(!equal_D0) begin
			data_wfw[0] = 1'b1;
		end
		if(!equal_D1) begin
			data_wfw[1] = 1'b1;
		end
	end
	
	parity_disk = wr_add % 3;
	P0_block = 12'b0;
	D0_block = 12'b0;
	D1_block = 12'b0;
	reg_wr_disk_0 = 12'b0;
	reg_wr_disk_1 = 12'b0;
	reg_wr_disk_2 = 12'b0;
	reg_en_wr_mem = 3'b0;
	if (data_wfw == 2'b11) begin  //write P, D0_enc, D1_enc
		// choose data blocks P0_block, D0_block, D1_block			
		P0_block = P;
		D0_block = D0_enc;
		D1_block = D1_enc;
		reg_en_wr_mem = WR_ALL;				
		
	end else if (data_wfw == 2'b01) begin //write P, D0_enc
		// choose data blocks P0_block and D0_block
		P0_block = P;
		D0_block = D0_enc;
		// enable disks of P0 and D0 according to parity disk
		if (parity_disk == 2'b00) begin
			reg_en_wr_mem = WR_DISK0_DISK1;				
		end else if (parity_disk == 2'b01) begin
			reg_en_wr_mem = WR_DISK0_DISK1;				
		end else if (parity_disk == 2'b10) begin
			reg_en_wr_mem = WR_DISK0_DISK2;				
		end
		
	end else if (data_wfw == 2'b10) begin //write P, D1_enc
		// choose data blocks P0_block and D1_block
		P0_block = P;
		D1_block = D1_enc;
		
		// enable disks of P0 and D1 according to parity disk
		if (parity_disk == 2'b00) begin
			reg_en_wr_mem = WR_DISK0_DISK2;				
		end else if (parity_disk == 2'b01) begin
			reg_en_wr_mem = WR_DISK1_DISK2;				
		end else if (parity_disk == 2'b10) begin
			reg_en_wr_mem = WR_DISK1_DISK2;				
		end			
	end
	
	if (parity_disk == 2'b00) begin
		reg_wr_disk_0 = P0_block;
		reg_wr_disk_1 = D0_block;
		reg_wr_disk_2 = D1_block;
	end else if (parity_disk == 2'b01) begin
		reg_wr_disk_0 = D0_block;
		reg_wr_disk_1 = P0_block;
		reg_wr_disk_2 = D1_block;
	end else if (parity_disk == 2'b10) begin
		reg_wr_disk_0 = D0_block;
		reg_wr_disk_1 = D1_block;
		reg_wr_disk_2 = P0_block;
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
	end else if(enable && (data_wfw != 2'b00)) begin
		wr_disk_0 <= reg_wr_disk_0;
		wr_disk_1 <= reg_wr_disk_1;
		wr_disk_2 <= reg_wr_disk_2;
		en_wr_mem <= reg_en_wr_mem;
		address   <= wr_add;
		out_valid <= 1'b1;
	end else if (mem_valid) begin
		out_valid <= 1'b0;
		out_mem_valid <= 1'b1;
		address   <= wr_add;
	end else begin
		wr_disk_0 <= 12'b0;
		wr_disk_1 <= 12'b0;
		wr_disk_2 <= 12'b0;
		en_wr_mem <= 3'b0;
		address   <= 8'b0;
		out_valid <= 1'b0;
		out_mem_valid <= 1'b0;
	end
	
end
endmodule