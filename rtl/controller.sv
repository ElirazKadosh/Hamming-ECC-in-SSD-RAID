module controller (
	input logic clk,
	input logic reset,

	input logic wr_en,
	input logic [15:0] write_data,
	input logic [7:0] address,
	input logic wr_done,

	input logic rd_en,
	input logic rd_done,

	input logic [2:0] disk_stat,
	input logic raid_done,

	output logic wr_en_out,
	output logic [15:0] write_data_out,
	output logic [7:0] address_out,

	output logic rd_en_out,

	output logic [2:0] disk_stat_out
);

// State Encoding
typedef enum logic [1:0] {
	IDLE  = 2'b00,
	WRITE = 2'b01,
	READ  = 2'b10,
	RAID  = 2'b11
} state_t;

state_t current_state, next_state;

// One-cycle pulse registers
logic wr_pulse, rd_pulse;
logic wr_en_ready, rd_en_ready;
logic [2:0] raid_ready, raid_pulse;

// State Transition Logic
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		current_state  <= IDLE;
		wr_en_out      <= 1'b0;
		rd_en_out      <= 1'b0;
		write_data_out <= 16'd0;
		address_out    <= 8'd0;
		disk_stat_out  <= 3'b111;
		wr_pulse       <= 1'b0;
		rd_pulse       <= 1'b0;
		raid_pulse	   <= 3'b111;
		wr_en_ready <= 1'b0;
		rd_en_ready <= 1'b0;
		raid_ready <= 3'b111;
	end else begin
		current_state <= next_state;
		
		wr_en_ready <= wr_en;
		rd_en_ready <= rd_en;
		raid_ready <= disk_stat;
		// Generate one-cycle pulse signals
		wr_pulse <= (current_state == IDLE && next_state == WRITE);
		rd_pulse <= (current_state == IDLE && next_state == READ);
		if (current_state == IDLE && next_state == RAID) begin
			raid_pulse <= raid_ready; 
		end else begin
			raid_pulse <= 3'b111;
		end
		// Default output values
		wr_en_out  <= 1'b0;
		rd_en_out  <= 1'b0;

		case (current_state)
			WRITE: begin
				write_data_out <= write_data;
				address_out    <= address;
				wr_en_out      <= wr_pulse;  // Output high for only one cycle
			end

			READ: begin
				address_out <= address;
				rd_en_out   <= rd_pulse;  // Output high for only one cycle
			end

			RAID: begin
				disk_stat_out <= raid_pulse;
			end
		endcase
	end
end

// Next State Logic
always_comb begin
	next_state = current_state;
	case (current_state)
		IDLE: begin
			if (wr_en_ready)
				next_state = WRITE;
			else if (rd_en_ready)
				next_state = READ;
			else if (raid_ready != 3'b111)
				next_state = RAID;
		end
		WRITE: begin
			if (wr_done)
				next_state = IDLE;
		end
		READ: begin
			if (rd_done)
				next_state = IDLE;
		end
		RAID: begin
			if (raid_done)
				next_state = IDLE;
		end
	endcase
end

endmodule