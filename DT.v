module DT(input 			clk,
          input			reset,
          output	reg		done,
          output	reg		sti_rd,
          output	reg 	[9:0]	sti_addr,
          input		[15:0]	sti_di,
          output	reg		res_wr,
          output	reg		res_rd,
          output	reg 	[13:0]	res_addr,
          output	reg 	[7:0]	res_do,
          input		[7:0]	res_di);

localparam FORWARD_PASS  = 1'b0;
localparam BACKWARD_PASS = 1'b1;

localparam FALSE = 1'b0;
localparam TRUE  = 1'b1;

`define STATE_NUM 3
localparam FORWARD_PASS_INIT  = 3'd0;
localparam FORWARD_COMPARE    = 3'd1;
localparam FORWARD_NEXT_ADDR  = 3'd2;
localparam BACKWARD_PASS_INIT = 3'd3;
localparam BACKWARD_COMPARE   = 3'd4;
localparam DONE               = 3'd5;

reg [`STATE_NUM-1:0] cur_state, next_state;
reg [6:0] loca_x, loca_y; //1,1 ~ 126,126
reg [2:0] counter, now_addr;

always @(posedge clk) begin
    if (!reset) begin
        cur_state <= FORWARD_PASS_INIT;
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        FORWARD_PASS_INIT: begin
            next_state = (counter == 3'd4) ? FORWARD_COMPARE : FORWARD_PASS_INIT;
        end
        FORWARD_COMPARE: begin
            next_state = (loca_x == 7'd126 && loca_y == 7'd126 && counter == 3'd0) ? BACKWARD_PASS_INIT : (loca_x == 7'd126 && counter == 3'd0) ? FORWARD_PASS_INIT : ((loca_x & 7'd15) == 7'd14 && counter == 3'd0) ? FORWARD_NEXT_ADDR : FORWARD_COMPARE;
        end
        FORWARD_NEXT_ADDR: begin
            next_state = (counter == 3'd2) ? FORWARD_COMPARE : FORWARD_NEXT_ADDR;
        end
        BACKWARD_PASS_INIT: begin
            next_state = (counter == 3'd5) ? BACKWARD_COMPARE : BACKWARD_PASS_INIT;
        end
        BACKWARD_COMPARE: begin
            next_state = (loca_x == 7'd1 && loca_y == 7'd1 && counter == 0) ? DONE : (loca_x == 7'd1 && counter == 0) ? BACKWARD_PASS_INIT : BACKWARD_COMPARE;
        end
        DONE: begin
            next_state = FORWARD_PASS_INIT;
        end
        default begin
            next_state = FORWARD_PASS_INIT;
        end
    endcase
end

(*KEEP = "TRUE"*) reg [31:0] rom_img_tmp[1:0];
reg [7:0] pixel_tmp[0:4];

wire [7:0] NW              = pixel_tmp[0];
wire [7:0] N               = pixel_tmp[1];
wire [7:0] NE              = pixel_tmp[2];
wire [7:0] W               = pixel_tmp[3];
wire [7:0] CENTER          = pixel_tmp[0];
wire [7:0] E               = pixel_tmp[1];
wire [7:0] SW              = pixel_tmp[2];
wire [7:0] S               = pixel_tmp[3];
wire [7:0] SE              = pixel_tmp[4];
wire [7:0] cmp0            = (NW < N) ? NW : N;
wire [7:0] cmp1            = (NE < W) ? NE : W;
wire [7:0] cmp2            = (E < SW) ? E : SW;
wire [7:0] cmp3            = (S < SE) ? S : SE;
wire [7:0] forward_center  = ((cmp0 < cmp1) ? cmp0 : cmp1) + 8'd1;
wire [7:0] backward_cmp    = ((cmp2 < cmp3) ? cmp2 : cmp3) + 8'd1;
wire [7:0] backward_center = (backward_cmp < pixel_tmp[0]) ? backward_cmp : pixel_tmp[0];

wire [6:0] addr_hight = loca_y - 7'd1;

always @(posedge clk) begin
    if (!reset) begin
        rom_img_tmp[0] <= 32'd0;
        rom_img_tmp[1] <= 32'd0;
        sti_rd         <= TRUE;
        sti_addr       <= 10'd0;
        pixel_tmp[0]   <= 8'd0;
        pixel_tmp[1]   <= 8'd0;
        pixel_tmp[2]   <= 8'd0;
        pixel_tmp[3]   <= 8'd0;
        pixel_tmp[4]   <= 8'd0;
        now_addr       <= 3'd0;
        loca_x         <= 7'd1;
        loca_y         <= 7'd1;
        res_wr         <= FALSE;
        res_rd         <= FALSE;
        res_addr       <= 14'd0;
        res_do         <= 8'd0;
        res_addr       <= 14'd0;
        counter        <= 3'd0;
        done           <= FALSE;
    end
    else begin
        case(cur_state)
            FORWARD_PASS_INIT: begin
                res_wr <= FALSE;
                case(counter)
                    3'd0: begin
                        res_rd   <= TRUE;
                        res_addr <= {addr_hight, 7'd0} + loca_x - 7'd1;
                        sti_addr <= {addr_hight, 3'd0} + now_addr;
                        counter  <= counter + 3'd1;
                    end
                    3'd1: begin
                        res_rd                <= TRUE;
                        res_addr              <= {addr_hight, 7'd0} + loca_x;
                        sti_addr              <= sti_addr + 10'd1;
                        rom_img_tmp[0][31:16] <= {sti_di[12:0], 3'b000};
                        pixel_tmp[0]          <= res_di;
                        counter               <= counter + 3'd1;
                    end
                    3'd2: begin
                        res_rd               <= TRUE;
                        res_addr             <= {addr_hight, 7'd0} + loca_x + 7'd1;
                        sti_addr             <= {loca_y, 3'd0} + now_addr;
                        rom_img_tmp[0][18:3] <= sti_di;
                        pixel_tmp[1]         <= res_di;
                        counter              <= counter + 3'd1;
                    end
                    3'd3: begin
                        res_rd                <= FALSE;
                        sti_addr              <= sti_addr + 10'd1;
                        rom_img_tmp[1][31:16] <= sti_di;
                        pixel_tmp[2]          <= res_di;
                        counter               <= counter + 3'd1;
                    end
                    3'd4: begin
                        res_rd         <= TRUE;
                        res_addr       <= {addr_hight, 7'd0} + loca_x + 7'd2;
                        rom_img_tmp[1] <= {rom_img_tmp[1][29:16],sti_di , 2'b00};
                        pixel_tmp[3]   <= {7'd0, rom_img_tmp[1][31]};
                        pixel_tmp[4]   <= {7'd0, rom_img_tmp[1][30]};
                        counter        <= 3'd0;
                    end
                    default begin
                        counter <= 3'd0;
                    end
                endcase
            end
            FORWARD_COMPARE: begin
                case(counter)
                    3'd0: begin
                        if (loca_x == 7'd126 && loca_y == 7'd126) begin
                            loca_x  <= loca_x;
                            loca_y  <= loca_y;
                            counter <= 3'd0;
                        end
                        else if (loca_x == 7'd126) begin
                            loca_x  <= 7'd1;
                            loca_y  <= loca_y + 7'd1;
                            counter <= 3'd0;
                        end
                        else begin
                            if ((loca_x & 7'd15) == 7'd14) begin
                                counter <= 3'd0;
                            end
                            else begin
                                counter <= counter + 3'd1;
                            end
                            loca_x <= loca_x + 7'd1;
                            loca_y <= loca_y;
                        end
                        if ((loca_x & 7'd15) == 7'd14) begin
                            now_addr <= now_addr + 3'd1;
                        end
                        else begin
                            now_addr <= now_addr;
                        end
                        rom_img_tmp[0] <= {rom_img_tmp[0][30:0], 1'b0};
                        rom_img_tmp[1] <= {rom_img_tmp[1][30:0], 1'b0};
                        pixel_tmp[0]   <= pixel_tmp[1];
                        pixel_tmp[1]   <= pixel_tmp[2];
                        pixel_tmp[2]   <= res_di;
                        pixel_tmp[4]   <= {7'd0, rom_img_tmp[1][31]};
                        res_rd         <= FALSE;
                        if (pixel_tmp[4] > 8'd0) begin
                            pixel_tmp[3] <= forward_center;
                            res_wr       <= TRUE;
                        end
                        else begin
                            pixel_tmp[3] <= pixel_tmp[4];
                            res_wr       <= FALSE;
                        end
                        res_addr <= {loca_y, 7'h00} + loca_x;
                        res_do   <= forward_center;
                    end
                    3'd1: begin
                        res_rd   <= TRUE;
                        res_wr   <= FALSE;
                        res_addr <= {addr_hight, 7'd0} + loca_x + 7'd2;
                        counter  <= 3'd0;
                    end
                    default begin
                        
                    end
                endcase
            end
            FORWARD_NEXT_ADDR: begin
                res_wr <= FALSE;
                case(counter)
                    3'd0: begin
                        sti_addr <= {addr_hight, 3'd0} + now_addr + 3'd1;
                        counter  <= counter + 3'd1;
                    end
                    3'd1: begin
                        sti_addr             <= {loca_y, 3'd0} + now_addr + 3'd1;
                        rom_img_tmp[0][15:0] <= sti_di;
                        counter              <= counter + 3'd1;
                    end
                    3'd2: begin
                        rom_img_tmp[1][15:0] <= sti_di;
                        counter              <= 3'd0;
                        res_rd               <= TRUE;
                        res_addr             <= {addr_hight, 7'd0} + loca_x + 7'd2;
                    end
                    default begin
                        counter <= 3'd0;
                    end
                endcase
            end
            BACKWARD_PASS_INIT: begin
                res_wr <= FALSE;
                case (counter)
                    3'd0: begin
                        counter  <= counter + 3'd1;
                        res_rd   <= TRUE;
                        res_addr <= {loca_y, 7'd0} + loca_x;
                    end
                    3'd1: begin
                        counter      <= counter + 3'd1;
                        res_rd       <= TRUE;
                        res_addr     <= res_addr + 14'd1;
                        pixel_tmp[0] <= res_di;
                    end
                    3'd2: begin
                        counter      <= counter + 3'd1;
                        res_rd       <= TRUE;
                        res_addr     <= {(loca_y + 7'd1), 7'd0} + loca_x + 7'd1;
                        pixel_tmp[1] <= res_di;
                    end
                    3'd3: begin
                        counter      <= counter + 3'd1;
                        res_rd       <= TRUE;
                        res_addr     <= res_addr - 14'd1;
                        pixel_tmp[4] <= res_di;
                    end
                    3'd4: begin
                        counter      <= counter + 3'd1;
                        res_rd       <= TRUE;
                        res_addr     <= res_addr - 14'd1;
                        pixel_tmp[3] <= res_di;
                    end
                    3'd5: begin
                        counter      <= 3'd0;
                        res_rd       <= TRUE;
                        res_addr     <= res_addr - 14'd1;
                        pixel_tmp[2] <= res_di;
                    end
                    default begin
                    end
                endcase
            end
            BACKWARD_COMPARE: begin
                case (counter)
                    3'd0: begin
                        res_rd   <= FALSE;
                        res_addr <= {loca_y, 7'h00} + loca_x;
                        res_do   <= backward_center;
                        if (pixel_tmp[0] > 8'd0) begin
                            pixel_tmp[1] <= backward_center;
                            res_wr       <= TRUE;
                        end
                        else begin
                            pixel_tmp[1] <= pixel_tmp[0];
                            res_wr       <= FALSE;
                        end
                        pixel_tmp[2] <= res_di;
                        pixel_tmp[3] <= pixel_tmp[2];
                        pixel_tmp[4] <= pixel_tmp[3];
                        if (loca_x == 7'd1) begin
                            loca_x  <= 7'd126;
                            loca_y  <= loca_y - 7'd1;
                            counter <= 3'd0;
                        end
                        else begin
                            loca_x  <= loca_x - 7'd1;
                            loca_y  <= loca_y;
                            counter <= counter + 3'd1;
                        end
                    end
                    3'd1: begin
                        counter  <= counter + 3'd1;
                        res_rd   <= TRUE;
                        res_wr   <= FALSE;
                        res_addr <= {loca_y, 7'h00} + loca_x;
                    end
                    3'd2: begin
                        counter      <= 3'd0;
                        res_rd       <= TRUE;
                        res_wr       <= FALSE;
                        res_addr     <= {(loca_y + 7'd1), 7'd0} + loca_x - 7'd2;
                        res_do       <= backward_center;
                        pixel_tmp[0] <= res_di;
                    end
                    default begin
                    end
                endcase
            end
            DONE: begin
                done <= TRUE;
            end
            default begin
                
            end
        endcase
    end
end

endmodule
