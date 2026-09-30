module uart_alu_test (
    input  wire clk,
    input  wire rst_n,

    input  wire uart_rx,
    output wire uart_tx,

    output reg led0
);

    // ============================================================
    // UART configuration
    // ============================================================

    localparam integer CLKS_PER_BIT = 234;


    // ============================================================
    // ALU
    // ============================================================

    function [31:0] alu_calc;
        input [31:0] A;
        input [31:0] B;
        input [3:0]  OP;

        begin
            case (OP)

                4'b0000: alu_calc = A + B;                       // ADD
                4'b0001: alu_calc = A - B;                       // SUB
                4'b0010: alu_calc = A & B;                       // AND
                4'b0011: alu_calc = A | B;                       // OR
                4'b0100: alu_calc = A ^ B;                       // XOR
                4'b0101: alu_calc = A << B[4:0];                 // SLL
                4'b0110: alu_calc = A >> B[4:0];                 // SRL
                4'b0111: alu_calc = $signed(A) >>> B[4:0];       // SRA
                4'b1000: alu_calc =
                    ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;  // SLT

                default:
                    alu_calc = 32'd0;

            endcase
        end
    endfunction


    // ============================================================
    // UART RX synchronizer
    // ============================================================

    reg rx_meta;
    reg rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end
        else begin
            rx_meta <= uart_rx;
            rx_sync <= rx_meta;
        end
    end


    // ============================================================
    // UART RX
    //
    // 8-N-1
    //
    // rx_byte_valid chỉ được tạo sau STOP bit
    // ============================================================

    localparam [1:0]
        RX_IDLE  = 2'd0,
        RX_START = 2'd1,
        RX_DATA  = 2'd2,
        RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_cnt;

    reg [7:0] rx_shift;
    reg [7:0] rx_byte;

    reg rx_byte_valid;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            rx_state      <= RX_IDLE;
            rx_clk_cnt    <= 16'd0;
            rx_bit_cnt    <= 3'd0;

            rx_shift      <= 8'd0;
            rx_byte       <= 8'd0;
            rx_byte_valid <= 1'b0;

        end
        else begin

            // pulse 1 clock
            rx_byte_valid <= 1'b0;

            case (rx_state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                RX_IDLE: begin

                    rx_clk_cnt <= 16'd0;
                    rx_bit_cnt <= 3'd0;

                    // START = LOW
                    if (rx_sync == 1'b0) begin
                        rx_state <= RX_START;
                    end

                end


                // ------------------------------------------------
                // START
                // ------------------------------------------------

                RX_START: begin

                    // sample giữa START bit
                    if (rx_clk_cnt == (CLKS_PER_BIT / 2) - 1) begin

                        rx_clk_cnt <= 16'd0;

                        if (rx_sync == 1'b0) begin

                            rx_bit_cnt <= 3'd0;
                            rx_state   <= RX_DATA;

                        end
                        else begin

                            rx_state <= RX_IDLE;

                        end

                    end
                    else begin

                        rx_clk_cnt <= rx_clk_cnt + 1'b1;

                    end

                end


                // ------------------------------------------------
                // DATA
                // ------------------------------------------------

                RX_DATA: begin

                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin

                        rx_clk_cnt <= 16'd0;

                        if (rx_bit_cnt == 3'd7) begin

                            // bit cuối = bit7
                            rx_shift[7] <= rx_sync;

                            rx_state <= RX_STOP;

                        end
                        else begin

                            rx_shift[rx_bit_cnt] <= rx_sync;
                            rx_bit_cnt <= rx_bit_cnt + 1'b1;

                        end

                    end
                    else begin

                        rx_clk_cnt <= rx_clk_cnt + 1'b1;

                    end

                end


                // ------------------------------------------------
                // STOP
                // ------------------------------------------------

                RX_STOP: begin

                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin

                        rx_clk_cnt <= 16'd0;

                        // STOP phải là HIGH
                        if (rx_sync == 1'b1) begin

                            rx_byte <= rx_shift;
                            rx_byte_valid <= 1'b1;

                        end

                        rx_state <= RX_IDLE;

                    end
                    else begin

                        rx_clk_cnt <= rx_clk_cnt + 1'b1;

                    end

                end


                default: begin
                    rx_state <= RX_IDLE;
                end

            endcase

        end
    end


    // ============================================================
    // PACKET FORMAT
    //
    // Byte 0 : AA
    // Byte 1 : A[7:0]
    // Byte 2 : A[15:8]
    // Byte 3 : A[23:16]
    // Byte 4 : A[31:24]
    // Byte 5 : B[7:0]
    // Byte 6 : B[15:8]
    // Byte 7 : B[23:16]
    // Byte 8 : B[31:24]
    // Byte 9 : OP
    // ============================================================

    reg [3:0]  packet_cnt;

    reg [31:0] alu_a;
    reg [31:0] alu_b;

    reg [3:0] alu_op;

    reg [31:0] response_result;
    reg        response_zero;

    // Pulse 1 clock, TX block chỉ đọc
    reg tx_start;


    // ============================================================
    // PACKET PARSER
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            packet_cnt <= 4'd0;

            alu_a <= 32'd0;
            alu_b <= 32'd0;
            alu_op <= 4'd0;

            response_result <= 32'd0;
            response_zero   <= 1'b0;

            tx_start <= 1'b0;

            // Active-low LED
            // 1 = OFF
            led0 <= 1'b1;

        end
        else begin

            // mặc định tx_start = 0
            tx_start <= 1'b0;

            if (rx_byte_valid) begin

                case (packet_cnt)

                    // ------------------------------------------------
                    // HEADER
                    // ------------------------------------------------

                    4'd0: begin

                        if (rx_byte == 8'hAA) begin
                            packet_cnt <= 4'd1;
                        end
                        else begin
                            packet_cnt <= 4'd0;
                        end

                    end


                    // ------------------------------------------------
                    // A
                    // ------------------------------------------------

                    4'd1:
                        alu_a[7:0] <= rx_byte;

                    4'd2:
                        alu_a[15:8] <= rx_byte;

                    4'd3:
                        alu_a[23:16] <= rx_byte;

                    4'd4:
                        alu_a[31:24] <= rx_byte;


                    // ------------------------------------------------
                    // B
                    // ------------------------------------------------

                    4'd5:
                        alu_b[7:0] <= rx_byte;

                    4'd6:
                        alu_b[15:8] <= rx_byte;

                    4'd7:
                        alu_b[23:16] <= rx_byte;

                    4'd8:
                        alu_b[31:24] <= rx_byte;


                    // ------------------------------------------------
                    // OP
                    // ------------------------------------------------

                    4'd9: begin

                        alu_op <= rx_byte[3:0];

                        // Tính kết quả từ A/B đã nhận đủ
                        response_result <=
                            alu_calc(
                                alu_a,
                                alu_b,
                                rx_byte[3:0]
                            );

                        response_zero <=
                            (
                                alu_calc(
                                    alu_a,
                                    alu_b,
                                    rx_byte[3:0]
                                ) == 32'd0
                            );

                        // zero = 1 -> LED sáng
                        if (
                            alu_calc(
                                alu_a,
                                alu_b,
                                rx_byte[3:0]
                            ) == 32'd0
                        ) begin
                            led0 <= 1'b0;
                        end
                        else begin
                            led0 <= 1'b1;
                        end

                        // Báo TX bắt đầu gửi response
                        tx_start <= 1'b1;

                        // Packet mới
                        packet_cnt <= 4'd0;

                    end


                    default: begin
                        packet_cnt <= 4'd0;
                    end

                endcase


                // Tăng packet counter
                if (packet_cnt != 4'd0 &&
                    packet_cnt != 4'd9) begin

                    packet_cnt <= packet_cnt + 1'b1;

                end

            end

        end
    end


    // ============================================================
    // UART TX
    //
    // Response:
    //
    // Byte 0 : 55
    // Byte 1 : result[7:0]
    // Byte 2 : result[15:8]
    // Byte 3 : result[23:16]
    // Byte 4 : result[31:24]
    // Byte 5 : zero
    // ============================================================

    localparam [1:0]
        TX_IDLE  = 2'd0,
        TX_START = 2'd1,
        TX_DATA  = 2'd2,
        TX_STOP  = 2'd3;

    reg [1:0]  tx_state;
    reg [15:0] tx_clk_cnt;
    reg [2:0]  tx_bit_cnt;
    reg [2:0]  tx_byte_cnt;

    reg [7:0] tx_byte;
    reg       tx_reg;

    assign uart_tx = tx_reg;


    // ============================================================
    // TX byte selection
    // ============================================================

    always @(*) begin

        case (tx_byte_cnt)

            3'd0:
                tx_byte = 8'h55;

            3'd1:
                tx_byte = response_result[7:0];

            3'd2:
                tx_byte = response_result[15:8];

            3'd3:
                tx_byte = response_result[23:16];

            3'd4:
                tx_byte = response_result[31:24];

            3'd5:
                tx_byte = {7'd0, response_zero};

            default:
                tx_byte = 8'h00;

        endcase

    end


    // ============================================================
    // TX FSM
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            tx_state    <= TX_IDLE;
            tx_clk_cnt  <= 16'd0;
            tx_bit_cnt  <= 3'd0;
            tx_byte_cnt <= 3'd0;

            tx_reg <= 1'b1;

        end
        else begin

            case (tx_state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                TX_IDLE: begin

                    tx_reg     <= 1'b1;
                    tx_clk_cnt <= 16'd0;
                    tx_bit_cnt <= 3'd0;

                    if (tx_start) begin

                        tx_byte_cnt <= 3'd0;
                        tx_state <= TX_START;

                    end

                end


                // ------------------------------------------------
                // START
                // ------------------------------------------------

                TX_START: begin

                    tx_reg <= 1'b0;

                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin

                        tx_clk_cnt <= 16'd0;
                        tx_bit_cnt <= 3'd0;

                        tx_state <= TX_DATA;

                    end
                    else begin

                        tx_clk_cnt <= tx_clk_cnt + 1'b1;

                    end

                end


                // ------------------------------------------------
                // DATA
                // ------------------------------------------------

                TX_DATA: begin

                    tx_reg <= tx_byte[tx_bit_cnt];

                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin

                        tx_clk_cnt <= 16'd0;

                        if (tx_bit_cnt == 3'd7) begin

                            tx_state <= TX_STOP;

                        end
                        else begin

                            tx_bit_cnt <= tx_bit_cnt + 1'b1;

                        end

                    end
                    else begin

                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end

                end


                // ------------------------------------------------
                // STOP
                // ------------------------------------------------

                TX_STOP: begin

                    tx_reg <= 1'b1;

                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin

                        tx_clk_cnt <= 16'd0;

                        if (tx_byte_cnt == 3'd5) begin

                            // hết response
                            tx_state <= TX_IDLE;

                        end
                        else begin

                            tx_byte_cnt <= tx_byte_cnt + 1'b1;
                            tx_state <= TX_START;

                        end

                    end
                    else begin

                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end

                end


                default: begin

                    tx_state <= TX_IDLE;
                    tx_reg <= 1'b1;

                end

            endcase

        end
    end

endmodule