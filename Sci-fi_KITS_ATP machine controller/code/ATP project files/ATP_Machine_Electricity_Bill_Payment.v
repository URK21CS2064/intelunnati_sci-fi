module ATP_Machine_Electricity_Bill_Payment (
    input wire clk,
    input wire reset,
    input wire card_inserted,     // Card insertion detection
    input wire [7:0] card_data,   // Card data (e.g., customer ID)
    input wire [3:0] pin,         // PIN for authorization
    input wire payment_1000,      // Payment in Rs 1000
    input wire payment_500,       // Payment in Rs 500
    input wire payment_100,       // Payment in Rs 100
    input wire payment_50,        // Payment in Rs 50
    output reg [7:0] display,     // Display output
    output reg payment_success,  // Payment success flag
    output reg payment_fail,     // Payment failure flag
    output reg payment_timeout   // Payment timeout flag
);
    // Internal signal declarations
    reg [3:0] state;
    reg authorized;
    reg payment_completed;
    reg excess_payment;
    reg [12:0] counter;
    reg [7:0] bill_amount;
    reg [7:0] payment_amount;
    reg [7:0] remaining_amount;
    reg [7:0] history_amount;

    // Constants
    localparam [7:0] BILL_AMOUNT = 8'hF4; // Total bill amount in cents
    localparam [12:0] TIMEOUT_COUNTER = 13'd39062; // Timeout duration in clock cycles

    // Clock process
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 4'b0000;
            authorized <= 1'b0;
            payment_completed <= 1'b0;
            excess_payment <= 1'b0;
            counter <= 13'd0;
            bill_amount <= 8'd0;
            payment_amount <= 8'd0;
            remaining_amount <= 8'd0;
            history_amount <= 8'd0;
        end else begin
            case (state)
                4'b0000: begin // Idle state
                    if (card_inserted) begin
                        state <= 4'b0010; // Transition to data entry state
                    end
                end
                4'b0010: begin // Data entry state
                    if (1'b1) begin
                        state <= 4'b0011; // Transition to validation state
                    end
                end
                4'b0011: begin // Validation state
                    if (1'b1) begin
                        state <= 4'b0100; // Transition to bill process state
                        bill_amount <= BILL_AMOUNT;
                        remaining_amount <= bill_amount;
                    end
                end
                4'b0100: begin // Bill process state
                    if (1'b1) begin
                        state <= 4'b0101; // Transition to payment by cash state
                        payment_amount <= 8'd0;
                    end
                end
                4'b0101: begin // Payment by cash state
                    if (payment_1000 || payment_500 || payment_100 || payment_50) begin
                        payment_amount <= payment_amount + (payment_1000 * 1000) + (payment_500 * 500) + (payment_100 * 100) + (payment_50 * 50);
                        remaining_amount <= remaining_amount - payment_amount;
                    end
                    if (remaining_amount == 0) begin
                        payment_completed <= 1'b1;
                    end
                    if (1'b1) begin
                        state <= 4'b0110; // Transition to acknowledge state
                    end
                end
                4'b0110: begin // Acknowledge state
                    if (1'b1) begin
                        state <= 4'b0111; // Transition to transaction process state
                    end
                end
                4'b0111: begin // Transaction process state
                    counter <= counter + 1;
                    if (counter == TIMEOUT_COUNTER) begin
                        state <= 4'b1101; // Transition to timeout state
                        payment_timeout <= 1'b1; // Set timeout flag
                    end else if (payment_completed) begin
                        state <= 4'b1000; // Transition to payment confirm state
                    end else begin
                        state <= 4'b1110; // Transition to fail state
                    end
                end
                4'b1000: begin // Payment confirm state
                    if (excess_payment) begin
                        state <= 4'b1001; // Transition to reduce if excess state
                    end else begin
                        state <= 4'b1011; // Transition to receipt state
                    end
                end
                4'b1001: begin // Reduce if excess state
                    if (1'b1) begin
                        state <= 4'b1010; // Transition to reduction process state
                    end
                end
                4'b1010: begin // Reduction process state
                    if (1'b1) begin
                        state <= 4'b1011; // Transition to receipt state
                    end
                end
                4'b1011: begin // Receipt state
                    if (1'b1) begin
                        state <= 4'b1100; // Transition to history state
                    end
                end
                4'b1100: begin // History state
                    if (1'b1) begin
                        state <= 4'b0000; // Transition back to idle state
                    end
                end
                4'b1101: begin // Timeout state
                    if (1'b1) begin
                        state <= 4'b0000; // Transition back to idle state
                    end
                end
                4'b1110: begin // Fail state
                    if (1'b1) begin
                        state <= 4'b0000; // Transition back to idle state
                    end
                end
                default: state <= 4'b0000; // Default case to handle any unexpected state
            endcase
        end
    end

    // Display output assignment
    always @* begin
        case (state)
            4'b0010, 4'b0100: display = card_data; // Display card data during data entry and bill process states
            4'b0101: display = remaining_amount; // Display remaining amount during payment by cash state
            4'b0110: display = bill_amount; // Display bill amount during acknowledge state
            4'b1000, 4'b1001, 4'b1010: display = payment_amount; // Display current payment amount during payment confirm and reduction process states
            4'b1011: display = {excess_payment, payment_amount}; // Display excess payment and payment amounts during receipt state
            4'b1100: display = history_amount; // Display history amount during history state
            default: display = 8'd0; // Display 0 in other states
        endcase
    end

    // Payment success and failure flag assignment
    always @* begin
        case (state)
            4'b1000, 4'b1011: begin
                payment_success = 1'b1;
                payment_fail = 1'b0; 
            end
            4'b1110: begin
                payment_success = 1'b0;
                payment_fail = 1'b1;
            end
            default: begin
                payment_success = 1'b0;
                payment_fail = 1'b0;
            end
        endcase
    end

endmodule