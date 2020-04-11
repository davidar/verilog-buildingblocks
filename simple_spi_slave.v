/*
This file is part of verilog-buildingblocks,
by David R. Piegdon <dgit@piegdon.de>

verilog-buildingblocks is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

verilog-buildingblocks is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with verilog-buildingblocks.  If not, see <https://www.gnu.org/licenses/>.
*/

`default_nettype none

/* Simple SPI slave implementation.
 *
 * SPI slave that exchanges a word of fixed @WIDTH with the master.
 * On @cs_start the value of @value_miso is copied into an internal buffer.
 * It is then shifted out to the bus on each SPI clock edge.
 * On @cs_stop the value shifted in from the master is provided in
 * @value_mosi. @value_valid indicates if it really is valid, i.e. that all
 * bits were received.
 *
 * @pin_ncs is active low.
 * Bit-order is MSB first.
 * Data is sampled on rising clock edge and latched out on falling edge,
 * i.e. CPOL=0, CPHA=0.
 */
module simple_spi_slave(
	input wire system_clk,

	input wire pin_ncs,
	input wire pin_clk,
	input wire pin_mosi,
	output wire pin_miso,
	output wire pin_miso_en,

	input wire [WIDTH-1:0] value_miso,
	output reg [WIDTH-1:0] value_mosi,
	output wire cs_start,
	output wire cs_stop,
	output wire value_valid);

	parameter WIDTH = 32;


	reg [$clog2(WIDTH+1)-1:0] bit_counter = 0;
	reg [WIDTH-1:0] value_miso_buffered = 0;

	reg [3:0] pin_ncs_stabilizer = 4'b1111;
	reg [3:0] pin_clk_stabilizer = 4'b0000;
	reg [3:0] pin_mosi_stabilizer = 0;

	wire cs_active = (pin_ncs_stabilizer[1:0] != 2'b11);
	assign cs_start = (pin_ncs_stabilizer[1:0] == 2'b01);
	assign cs_stop  = (pin_ncs_stabilizer[1:0] == 2'b10);

	wire sample = (pin_clk_stabilizer[1:0] == 2'b10);
	wire latch_out = (pin_clk_stabilizer[1:0] == 2'b01);

	assign pin_miso = value_miso_buffered[WIDTH-1];
	assign pin_miso_en = cs_active && !pin_ncs;

	assign value_valid = (cs_stop && (bit_counter == WIDTH));


	always @(posedge system_clk) begin
		pin_ncs_stabilizer  <= { pin_ncs,  pin_ncs_stabilizer[3:1]  };
		pin_clk_stabilizer  <= { pin_clk,  pin_clk_stabilizer[3:1]  };
		pin_mosi_stabilizer <= { pin_mosi, pin_mosi_stabilizer[3:1] };

		if(cs_active) begin
			if(cs_start) begin
				value_miso_buffered <= value_miso;
				bit_counter <= 0;
			end else if(!cs_stop) begin
				if(bit_counter < WIDTH) begin
					if(sample) begin
							value_mosi <= { value_mosi[WIDTH-2:0], pin_mosi_stabilizer[0] };
							bit_counter <= bit_counter+1;
					end else if(latch_out) begin
							value_miso_buffered <= { value_miso_buffered[WIDTH-2:0], 1'b0};
					end
				end
			end
		end
	end

endmodule
