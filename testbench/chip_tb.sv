`timescale 1ns / 1ps

module chip_tb;
// Clock and Reset
reg clk;
reg reset;

// System Inputs
reg wr_en;
reg [15:0] wr_data;
reg [7:0] address, corrupted_address;
reg rd_en;
reg [2:0] disk_stat;
reg [11:0] corrupted_data_D0, corrupted_data_D1;
reg [1:0] disks_to_write;

// my inputs instead of CTRL

// System Outputs
wire [15:0] data_read;


wire [7:0] enc_to_par_address, par_to_rfw_address, rfw_out_address, reader_out_address, mem_to_reader_address
		,check_out_address, compare_out_address_D0, compare_out_address_D1, normal_to_writer_address, writer_out_address, read_normal_out_address,
		fix_out_address, wfr_out_address, read_raid_out_address, write_raid_out_address, ctrl_address;

wire [11:0] enc_to_par_enc_D0, enc_to_par_enc_D1, par_to_rfw_enc_D0,par_to_rfw_enc_D1, par_to_rfw_parity, rfw_out_D0,rfw_out_D1, rfw_out_P,
		rfw_to_check_D0_old,rfw_to_check_D1_old, mem_to_reader_data_A, mem_to_reader_data_B, reader_to_mini_read_data_A, reader_to_mini_read_data_B,
		check_out_D0, check_out_D1, check_out_P, check_out_D0_old, check_out_D1_old, compare_to_write_D0_0, compare_to_write_D0_1, compare_to_write_D1_0, compare_to_write_D1_1
		, compare_to_write_P_0, compare_to_write_P_1, reader_out_D0,reader_out_D1,reader_out_P, mem_out_D0, mem_out_D1, mem_out_P, normal_to_writer_disk0,
		normal_to_writer_disk1, normal_to_writer_disk2,
		writer_to_mem_disk0, writer_to_mem_disk1, writer_to_mem_disk2, read_normal_to_check_D0, read_normal_to_check_D1, fix_out_D0, fix_out_D1,
		wfr_to_writer_disk0, wfr_to_writer_disk1, wfr_to_writer_disk2, wfr_to_decode_D0, wfr_to_decode_D1, fix_out_D0_old, fix_out_D1_old,
		wfr_out_D0_old, wfr_out_D1_old, writer_out_D0_old, writer_out_D1_old, mem_out_D0_old, mem_out_D1_old, read_raid_to_writer_data_A, read_raid_to_writer_data_B,
		write_raid_to_writer_disk0, write_raid_to_writer_disk1, write_raid_to_writer_disk2;

wire [1:0] rfw_to_reader_en_rd_mem, reader_to_mem_en_rd_mem, read_normal_to_reader_en_rd_mem, read_raid_en_rd_mem;
wire D0_enc_valid, D1_enc_valid, parity_data_valid, reader_to_mem_valid,  reader_to_normal_read_valid,reader_to_rfw_valid,
		reader_to_read_raid_valid, rfw_to_check_valid, rfw_to_reader_valid, mem_to_reader_valid, mem_to_writer_valid,
		read_normal_to_check_valid, equal_D0, equal_D1, compare_valid_out_D0, compare_valid_out_D1, normal_to_ctrl_valid,
		normal_to_writer_valid, writer_to_normal_valid, writer_to_read_valid, writer_to_raid_valid, writer_out_valid, check_out_valid_D0, check_out_valid_D1,
		read_normal_to_reader_valid, fix_out_valid_D0, fix_out_valid_D1, wfr_to_writer_valid, wfr_to_decode_valid, decode_valid_D0, decode_valid_D1,
		wfr_to_decode_write_D0, wfr_to_decode_write_D1, check_out_write_valid, check_out_read_valid, mem_to_read_raid_enable, read_raid_to_reader_valid,
		read_raid_to_write_raid_last, read_raid_to_writer_valid, write_raid_to_writer_valid, write_raid_to_read_raid_valid, write_raid_to_ctrl_done_recovery,
		ctrl_wr_en, ctrl_rd_en;
wire [3:0] check_out_synd_D0, check_out_synd_D1;
wire [2:0] normal_to_writer_en_wr_mem, writer_to_mem_en_wr_mem, wfr_to_writer_en_wr_mem, mem_to_read_raid_disk_stat_out, read_raid_to_write_raid_disk_stat,
		write_raid_to_writer_en_wr_mem, ctrl_disk_stat;
wire [15:0] ctrl_data;

//address will be going from D0 paths
// Hamming Encoder (2 Instances)

controller controller_(
.clk(clk), .reset(reset), .wr_en(wr_en), .write_data(wr_data), .address(address), .wr_done(normal_to_ctrl_valid ||(compare_valid_out_D0 && compare_valid_out_D1 && equal_D0 && equal_D1)), 
.rd_en(rd_en), .rd_done(decode_valid_D0 & decode_valid_D1), .disk_stat(disk_stat), .raid_done(write_raid_to_ctrl_done_recovery),
.wr_en_out(ctrl_wr_en), .write_data_out(ctrl_data), .address_out(ctrl_address), .rd_en_out(ctrl_rd_en), .disk_stat_out(ctrl_disk_stat)

);

hamming_encoder hamming_enc_D0 (
	.clk(clk), .reset(reset), .enable(ctrl_wr_en), .data_in(ctrl_data[15:8]), .address_in(ctrl_address), .enc_data(enc_to_par_enc_D0), 
	.address_out(enc_to_par_address) ,.enc_data_valid(D0_enc_valid)
);

hamming_encoder hamming_enc_D1 (
	.clk(clk), .reset(reset), .enable(ctrl_wr_en), .data_in(ctrl_data[7:0]), .address_in(ctrl_address), .enc_data(enc_to_par_enc_D1) ,
	.address_out() , .enc_data_valid(D1_enc_valid)
);

parity_calculator parity_calc (
	.clk(clk), .reset(reset), .enable(D0_enc_valid & D1_enc_valid), .D0_enc_in(enc_to_par_enc_D0), .D1_enc_in(enc_to_par_enc_D1),.address_in(enc_to_par_address), 
	.address_out(par_to_rfw_address) , .P(par_to_rfw_parity) ,.parity_data_valid(parity_data_valid), .D0_enc_out(par_to_rfw_enc_D0), .D1_enc_out(par_to_rfw_enc_D1)
);

read_for_write read_for_write_(
	.clk(clk), .reset(reset), .rd_valid(parity_data_valid), .rd_add(par_to_rfw_address | reader_out_address),
	.D0_enc_in(par_to_rfw_enc_D0 | reader_out_D0), .D1_enc_in(par_to_rfw_enc_D1 | reader_out_D1),.P_in(par_to_rfw_parity | reader_out_P),
	.mem_valid(reader_to_rfw_valid), .in_rd_valid_data_A(reader_to_mini_read_data_A), .in_rd_valid_data_B(reader_to_mini_read_data_B), .D0_enc_out(rfw_out_D0), .D1_enc_out(rfw_out_D1),
	.P_out(rfw_out_P),.rd_valid_data_A(rfw_to_check_D0_old), .rd_valid_data_B(rfw_to_check_D1_old), .out_mem_valid(rfw_to_check_valid), .out_valid(rfw_to_reader_valid),
	.add(rfw_out_address), .en_rd_mem(rfw_to_reader_en_rd_mem)
);
// mini read - indicates one of the read_for_write read_normal or read_raid (they all get the data read from disk reader only differ is the valid for the correct one)
// Hamming Checker (2 Instances)
hamming_checker hamming_chk_D0 (
	.clk(clk), .reset(reset), .enc_data_old_in(rfw_to_check_D0_old | read_normal_to_check_D0), .valid_normal_write(rfw_to_check_valid), .valid_normal_read(read_normal_to_check_valid),
	.D0_enc_in(rfw_out_D0), .D1_enc_in(rfw_out_D1), .P_in(rfw_out_P), .address_in(rfw_out_address | read_normal_out_address), .address_out(check_out_address),
	.valid_normal_write_out(check_out_write_valid), .valid_normal_read_out(check_out_read_valid),
	.D0_enc_out(check_out_D0), .D1_enc_out(check_out_D1),
	.P_out(check_out_P), .check_valid(check_out_valid_D0), .enc_data_old_out(check_out_D0_old), .synd(check_out_synd_D0)
);

hamming_checker hamming_chk_D1 (
	.clk(clk), .reset(reset), .enc_data_old_in(rfw_to_check_D1_old | read_normal_to_check_D1), .valid_normal_write(rfw_to_check_valid), .valid_normal_read(read_normal_to_check_valid),
	.D0_enc_in(rfw_out_D0), .D1_enc_in(rfw_out_D1), .P_in(rfw_out_P), .address_in(rfw_out_address | read_normal_out_address), .address_out(),
	.valid_normal_write_out(), .valid_normal_read_out(),
	.D0_enc_out(), .D1_enc_out(), .P_out(), .check_valid(check_out_valid_D1),
	.enc_data_old_out(check_out_D1_old), .synd(check_out_synd_D1)
);
// Compare Encoded Blocks (2 Instances)
//also here sending D0 D1 and P just from one of the blocks don't need both
compare_encoded_blocks compare_enc_D0 (
	.clk(clk), .reset(reset), .enable(check_out_write_valid && check_out_valid_D0 && (check_out_synd_D0 == 4'b0)),
	.enc_data(check_out_D0), .enc_data_old(check_out_D0_old), .address_in(check_out_address),
	.D0_enc_in(check_out_D0), .D1_enc_in(check_out_D1), .P_in(check_out_P), .address_out(compare_out_address_D0), 
	.D0_enc_out(compare_to_write_D0_0), .D1_enc_out(compare_to_write_D1_0), .P_out(compare_to_write_P_0), .compare_valid(compare_valid_out_D0), .equal(equal_D0)
);

compare_encoded_blocks compare_enc_D1 (
	.clk(clk), .reset(reset), .enable(check_out_write_valid && check_out_valid_D1 && (check_out_synd_D1 == 4'b0)),
	.enc_data(check_out_D1), .enc_data_old(check_out_D1_old), .address_in(check_out_address),
	.D0_enc_in(check_out_D0), .D1_enc_in(check_out_D1), .P_in(check_out_P), .address_out(compare_out_address_D1),
	.D0_enc_out(compare_to_write_D0_1), .D1_enc_out(compare_to_write_D1_1), .P_out(compare_to_write_P_1), .compare_valid(compare_valid_out_D1), .equal(equal_D1)
);

write_normal write_normal_(
	.clk(clk), .reset(reset),
	.enable((check_out_synd_D0 != 4'b0 && check_out_synd_D1 != 4'b0 && check_out_write_valid) || ((compare_valid_out_D0 || compare_valid_out_D1) && (!equal_D0 || !equal_D1))),
	.P(compare_to_write_P_0 | compare_to_write_P_1 | check_out_P), .D0_enc(compare_to_write_D0_0 | compare_to_write_D0_1 | check_out_D0),
	.D1_enc(compare_to_write_D1_0 | compare_to_write_D1_1 | check_out_D1), .wr_add(check_out_address | compare_out_address_D0 | compare_out_address_D1),
	.mem_valid(writer_to_normal_valid), .synd_D0(check_out_synd_D0), .synd_D1(check_out_synd_D1), .equal_D0(equal_D0), .equal_D1(equal_D1),
	.wr_disk_0(normal_to_writer_disk0), .wr_disk_1(normal_to_writer_disk1), .wr_disk_2(normal_to_writer_disk2), .en_wr_mem(normal_to_writer_en_wr_mem),
	.out_valid(normal_to_writer_valid), .out_mem_valid(normal_to_ctrl_valid), .address(normal_to_writer_address)
);
// from here checking read normal path

read_normal read_normal_(
	.clk(clk), .reset(reset), .rd_valid(ctrl_rd_en), .rd_add(ctrl_address | reader_out_address), .mem_valid(reader_to_normal_read_valid), 
	.in_rd_valid_data_A(reader_to_mini_read_data_A), .in_rd_valid_data_B(reader_to_mini_read_data_B),
	.rd_valid_data_A(read_normal_to_check_D0), .rd_valid_data_B(read_normal_to_check_D1), .out_mem_valid(read_normal_to_check_valid),
	.out_valid(read_normal_to_reader_valid), .add(read_normal_out_address), .en_rd_mem(read_normal_to_reader_en_rd_mem)
);


// Hamming Fixer (2 Instances)
hamming_fixer hamming_fix_D0 (
	.clk(clk), .reset(reset), .enable((check_out_synd_D0 != 4'b0) && check_out_read_valid), .bad_data(check_out_D0_old),
	.enc_data_old_in(check_out_D0_old),  .synd(check_out_synd_D0), 	.address_in(check_out_address), .address_out(fix_out_address),
	.enc_data_old_out(fix_out_D0_old), .fix_valid(fix_out_valid_D0), .corrected_data(fix_out_D0)
);

hamming_fixer hamming_fix_D1 (
	.clk(clk), .reset(reset), .enable((check_out_synd_D1 != 4'b0) && check_out_read_valid),
	.bad_data(check_out_D1_old), .enc_data_old_in(check_out_D1_old), .synd(check_out_synd_D1),
	.address_in(check_out_address), .address_out(), .enc_data_old_out(fix_out_D1_old), .fix_valid(fix_out_valid_D1), .corrected_data(fix_out_D1)
);

write_for_read write_for_read_(
	.clk(clk), .reset(reset), .corrected_data_D0(fix_out_D0), .corrected_data_D1(fix_out_D1), .wr_add(fix_out_address), 
	.enc_data_old_D0_in(fix_out_D0_old | check_out_D0_old),	.enc_data_old_D1_in(fix_out_D1_old | check_out_D1_old),
	.write_D0(fix_out_valid_D0), .write_D1(fix_out_valid_D1),
	.mem_valid(writer_to_read_valid), .enc_data_old_D0_out(wfr_out_D0_old), .enc_data_old_D1_out(wfr_out_D1_old),
	.write_D0_out(wfr_to_decode_write_D0), .write_D1_out(wfr_to_decode_write_D1), .corrected_data_D0_out(wfr_to_decode_D0),
	.corrected_data_D1_out(wfr_to_decode_D1), .wr_disk_0(wfr_to_writer_disk0), .wr_disk_1(wfr_to_writer_disk1), .wr_disk_2(wfr_to_writer_disk2),
	.en_wr_mem(wfr_to_writer_en_wr_mem), .out_valid(wfr_to_writer_valid), .out_mem_valid(wfr_to_decode_valid), .address(wfr_out_address)
);

// Hamming Decoder (2 Instances)
hamming_decoder hamming_decode_D0 (
	.clk(clk), .reset(reset), .wfr_to_decode_valid(wfr_to_decode_valid), .check_out_valid_D0(check_out_valid_D0), .check_out_valid_D1(check_out_valid_D1), 
	.check_out_synd_D0(check_out_synd_D0), .check_out_synd_D1(check_out_synd_D1), .sel_blk(wfr_to_decode_valid && wfr_to_decode_write_D0), .check_out_read_valid(check_out_read_valid),
	.enc_data(check_out_D0_old | wfr_out_D0_old), .corrected_data(wfr_to_decode_D0), .decode_valid(decode_valid_D0), .dec_data(data_read[15:8])
);

hamming_decoder hamming_decode_D1 (
	.clk(clk), .reset(reset), .wfr_to_decode_valid(wfr_to_decode_valid), .check_out_valid_D0(check_out_valid_D0), .check_out_valid_D1(check_out_valid_D1),
	.check_out_synd_D0(check_out_synd_D0), .check_out_synd_D1(check_out_synd_D1), .sel_blk(wfr_to_decode_valid && wfr_to_decode_write_D1), .check_out_read_valid(check_out_read_valid),
	.enc_data(check_out_D1_old | wfr_out_D1_old), .corrected_data(wfr_to_decode_D1), .decode_valid(decode_valid_D1), .dec_data(data_read[7:0])
);

memory mem (
	.clk(clk), .reset(reset), .wr_disk0(writer_to_mem_disk0), .wr_disk1(writer_to_mem_disk1), .wr_disk2(writer_to_mem_disk2), .en_wr_mem(writer_to_mem_en_wr_mem),
	.address(writer_out_address), .wr_valid(writer_out_valid), .en_rd_mem(reader_to_mem_en_rd_mem), .add(reader_out_address), .rd_valid(reader_to_mem_valid),
	.D0_enc_in(reader_out_D0), .D1_enc_in(reader_out_D1), .P_in(reader_out_P), .disk_stat(ctrl_disk_stat),
	.corrupted_data_D0(corrupted_data_D0), .corrupted_data_D1(corrupted_data_D1), .corrupted_address(corrupted_address), .disks_to_write(disks_to_write),
	.enc_data_old_D0_in(writer_out_D0_old), .enc_data_old_D1_in(writer_out_D1_old), .zero_done(mem_to_read_raid_enable), .disk_stat_out(mem_to_read_raid_disk_stat_out),
	.enc_data_old_D0_out(mem_out_D0_old), .enc_data_old_D1_out(mem_out_D1_old), .D0_enc_out(mem_out_D0), .D1_enc_out(mem_out_D1), .P_out(mem_out_P), 
	.out_address(mem_to_reader_address),  .out_valid_rd(mem_to_reader_valid),
	.out_valid_wr(mem_to_writer_valid), .out_rd_valid_A(mem_to_reader_data_A), .out_rd_valid_B(mem_to_reader_data_B)
);

read_raid read_raid_ (
.clk(clk), .reset(reset), .enable(mem_to_read_raid_enable), .disk_stat(mem_to_read_raid_disk_stat_out), 
.mem_valid(reader_to_read_raid_valid), .in_rd_valid_data_A(reader_to_mini_read_data_A), .in_rd_valid_data_B(reader_to_mini_read_data_B),
.write_done(write_raid_to_read_raid_valid), .rd_valid_data_A(read_raid_to_writer_data_A), .rd_valid_data_B(read_raid_to_writer_data_B), 
.out_mem_valid(read_raid_to_writer_valid), .last_op(read_raid_to_write_raid_last), .disk_stat_out(read_raid_to_write_raid_disk_stat), .out_valid(read_raid_to_reader_valid),
.add(read_raid_out_address), .en_rd_mem(read_raid_en_rd_mem)
);

disk_reader disk_rd (
	.clk(clk), .reset(reset), .out_valid_rd(mem_to_reader_valid), .D0_enc_in(rfw_out_D0 | mem_out_D0), .D1_enc_in(rfw_out_D1 | mem_out_D1), .P_in(rfw_out_P | mem_out_P),
	.normal_rd_valid_data_A(mem_to_reader_data_A), .normal_rd_valid_data_B(mem_to_reader_data_B), .normal_add(read_normal_out_address), 
	.normal_en_rd_mem(read_normal_to_reader_en_rd_mem), .normal_out_valid(read_normal_to_reader_valid),
	.write_rd_valid_data_A(mem_to_reader_data_A), .write_rd_valid_data_B(mem_to_reader_data_B), .write_add(rfw_out_address | mem_to_reader_address),
	.write_en_rd_mem(rfw_to_reader_en_rd_mem), .write_out_valid(rfw_to_reader_valid), .raid_rd_valid_data_A(mem_to_reader_data_A),
	.raid_rd_valid_data_B(mem_to_reader_data_B), .raid_add(read_raid_out_address), .raid_en_rd_mem(read_raid_en_rd_mem), .raid_out_valid(read_raid_to_reader_valid), 
	.D0_enc_out(reader_out_D0), .D1_enc_out(reader_out_D1),	.P_out(reader_out_P),
	.normal_mem_valid(reader_to_normal_read_valid), .write_mem_valid(reader_to_rfw_valid),
	.raid_mem_valid(reader_to_read_raid_valid), .rd_valid_data_A(reader_to_mini_read_data_A), .rd_valid_data_B(reader_to_mini_read_data_B),
	.rd_valid(reader_to_mem_valid), .address(reader_out_address), .en_rd_mem(reader_to_mem_en_rd_mem)
);

write_raid write_raid_ (
.clk(clk), .reset(reset), .enable(read_raid_to_writer_valid), .raid_data(read_raid_to_writer_data_A ^ read_raid_to_writer_data_B),
.disk_stat(read_raid_to_write_raid_disk_stat), .mem_valid(writer_to_raid_valid), .last_op(read_raid_to_write_raid_last), .wr_disk_0(write_raid_to_writer_disk0),
.wr_disk_1(write_raid_to_writer_disk1), .wr_disk_2(write_raid_to_writer_disk2), .en_wr_mem(write_raid_to_writer_en_wr_mem),
.out_valid(write_raid_to_writer_valid), .out_mem_valid(write_raid_to_read_raid_valid), .done_recovery(write_raid_to_ctrl_done_recovery), .address(write_raid_out_address)
);

disk_writer disk_wr (
	.clk(clk), .reset(reset), .out_valid_wr(mem_to_writer_valid), .enc_data_old_D0_in(wfr_out_D0_old | mem_out_D0_old), .enc_data_old_D1_in(wfr_out_D1_old | mem_out_D1_old), 
	.normal_wr_disk_0(normal_to_writer_disk0), .normal_wr_disk_1(normal_to_writer_disk1),
	.normal_wr_disk_2(normal_to_writer_disk2), .normal_en_wr_mem(normal_to_writer_en_wr_mem), .normal_address(normal_to_writer_address), .normal_out_valid(normal_to_writer_valid),
	.read_wr_disk_0(wfr_to_writer_disk0), .read_wr_disk_1(wfr_to_writer_disk1), .read_wr_disk_2(wfr_to_writer_disk2), .read_en_wr_mem(wfr_to_writer_en_wr_mem), 
	.read_address(wfr_out_address), .read_out_valid(wfr_to_writer_valid), .raid_wr_disk_0(write_raid_to_writer_disk0), .raid_wr_disk_1(write_raid_to_writer_disk1),
	.raid_wr_disk_2(write_raid_to_writer_disk2), .raid_en_wr_mem(write_raid_to_writer_en_wr_mem), .raid_address(write_raid_out_address), .raid_out_valid(write_raid_to_writer_valid), .enc_data_old_D0_out(writer_out_D0_old), .enc_data_old_D1_out(writer_out_D1_old), 
	.normal_mem_valid(writer_to_normal_valid), .read_mem_valid(writer_to_read_valid),
	.raid_mem_valid(writer_to_raid_valid), .wr_disk_0(writer_to_mem_disk0), .wr_disk_1(writer_to_mem_disk1), .wr_disk_2(writer_to_mem_disk2),
	.en_wr_mem(writer_to_mem_en_wr_mem), .address(writer_out_address), .wr_valid(writer_out_valid)
);



// Clock Generation
always #5 clk = ~clk;
// Test Sequence
initial begin
	$display("Starting RAID5 System Testbench");
	clk = 0;
	reset = 1'b1;
	wr_en = 1'b0;
	rd_en = 1'b0;
	address = 8'b0;
	disk_stat = 3'b111;
	disks_to_write = 2'b00;
	corrupted_address = 8'b0;
	corrupted_data_D0 = 12'b0;
	corrupted_data_D1 = 12'b0;
	#5
	reset = 1'b0;
	disk_stat = 3'b111;
	
	// Write Data to RAID5 System
	$display("Writing Data to RAID5...");
	
	
	//test for WRITE full path no errors
	wr_en = 1'b1;
	wr_data = 16'h2234;
	address = 8'b0;
	#10
	wr_en = 1'b0;
	
	#200
	
	//test for WRITE full path no errors
	wr_en = 1'b1;
	wr_data = 16'h1234;
	address = 8'b1;
	#10
	wr_en = 1'b0;
	
	#200
			
	wr_en = 1'b1;
	wr_data = 16'h1254;
	address = 8'b0;
	#10
	wr_en = 1'b0;
	
	#200		
	
	/*
	//test for WRITE full path no errors
	wr_en = 1;
	wr_data = 16'h4567;
	address = 8'b10;
	#10
	wr_en = 0;
	
	#200
		
	//test for WRITE full path no errors
	wr_en = 1;
	wr_data = 16'h2210;
	address = 8'b11;
	#10
	wr_en = 0;

	#200
	*/
	
	// make error in 2 disk	
	disks_to_write = 2'b11;
	corrupted_address = 8'b1;
	corrupted_data_D0 = 12'b000110011010;
	corrupted_data_D1 = 12'b001100101101;
	#10
	disks_to_write = 2'b0;	
	/////
	
	//try rewrite the same thing as before the error we made
	wr_en = 1'b1;
	wr_data = 16'h1234;
	address = 8'b1;
	#10
	wr_en = 1'b0;
	
	#200	
			
	// make error in 1 disk	to check full path of writing
	disks_to_write = 2'b01;
	corrupted_address = 8'b1;
	corrupted_data_D0 = 12'b000110011010;
	#10
	disks_to_write = 2'b0;	
	/////
	rd_en = 1'b1;
	address = 8'b1;
	#10
	rd_en = 1'b0;
	
	#200
	
	//try rewrite the same thing as before the error we made
	wr_en = 1'b1;
	wr_data = 16'h1234;
	address = 8'b1;
	#10
	wr_en = 1'b0;
	
	#200
	
	wr_en = 1'b1;
	wr_data = 16'h1894;
	address = 8'b1;
	#10
	wr_en = 1'b0;
	
	#200
	/*
	/*
	#200
	//test for WRITE 1 same 1 diff
	wr_en = 1;
	wr_data = 16'h2234;
	address = 8'b1;
	#10
	wr_en = 0;
	
	#200
	//test for WRITE 1 same 1 diff
	wr_en = 1;
	wr_data = 16'h2210;
	address = 8'b1;
	#10
	wr_en = 0;
	
	#200		
			
	disks_to_write = 2'b01;
	corrupted_address = 8'b10;
	corrupted_data_D0 = 12'b010010101111;
	
	#10
	disks_to_write = 2'b0;
	rd_en = 1;
	address = 8'b10;
	#10
	rd_en = 0;
	
	#200
	disks_to_write = 2'b11;
	corrupted_address = 8'b10;
	corrupted_data_D0 = 12'b010010101111;
	corrupted_data_D1 = 12'b011000010101;

	#10
	disks_to_write = 2'b0;
	rd_en = 1;
	address = 8'b10;
	#10
	rd_en = 0;
	#200		
			
	*/	
			
	disk_stat = 3'b101;
	#10
	disk_stat = 3'b111;
	#2000
	
	
	$stop;
end
endmodule