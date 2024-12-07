
import mnist_pkg::*;

module dense #(
    parameter INPUT_VECTOR_LENGTH  = 196,
              OUTPUT_VECTOR_LENGTH = 128,
              load_weights         = 1,
              weight_file          = "dense_weights.hex",
              bias_file            = "dense_biases.hex",
              relu                 = 1,
              INDUCE_FAILURE_DENSE = 0
)(
    input  logic clock,
    input  logic reset_n,
    feature_if features_in,
    feature_if features_out
);

//-------------------------------------------------------------------//
// Signal Declarations
//-------------------------------------------------------------------//
logic [$clog2(INPUT_VECTOR_LENGTH)-1:0] input_index;
logic [$clog2(OUTPUT_VECTOR_LENGTH)-1:0] output_index;

feature_type input_buffer[INPUT_VECTOR_LENGTH];
feature_type output_buffer[OUTPUT_VECTOR_LENGTH];
weight_type weight_memory[OUTPUT_VECTOR_LENGTH][INPUT_VECTOR_LENGTH];
feature_type bias_memory[OUTPUT_VECTOR_LENGTH];

logic receive, send;

typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;
rx_state_type rx_state, next_rx_state;
tx_state_type tx_state, next_tx_state;

//-------------------------------------------------------------------//
// Weight and Bias Initialization
//-------------------------------------------------------------------//
initial begin
    // Initialize memory with default values
    for (int i = 0; i < OUTPUT_VECTOR_LENGTH; i++) begin
        for (int j = 0; j < INPUT_VECTOR_LENGTH; j++) begin
            weight_memory[i][j] = 0;
        end
        bias_memory[i] = 0;
    end

    // Load from files if enabled
    if (load_weights) begin
        if (weight_file != "") $readmemh(weight_file, weight_memory);
        if (bias_file != "") $readmemh(bias_file, bias_memory);
    end
end

//-------------------------------------------------------------------//
// Input State Machine
//-------------------------------------------------------------------//
always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
        input_index <= 0;
        rx_state <= RX_IDLE;
    end else begin
        rx_state <= next_rx_state;

        if (features_in.valid && features_in.ready && input_index < INPUT_VECTOR_LENGTH) begin
            input_buffer[input_index] <= features_in.features[0];
            input_index <= input_index + 1;
        end
    end
end

always_comb begin
    case (rx_state)
        RX_IDLE: next_rx_state = (receive) ? RX_RECV : RX_IDLE;
        RX_RECV: next_rx_state = (input_index == INPUT_VECTOR_LENGTH - 1) ? RX_DONE : RX_RECV;
        RX_DONE: next_rx_state = RX_IDLE;
        default: next_rx_state = RX_IDLE;
    endcase
end

assign features_in.ready = (rx_state == RX_RECV);

//-------------------------------------------------------------------//
// Dense Layer Computation
//-------------------------------------------------------------------//
integer i, j;
always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
        for (i = 0; i < OUTPUT_VECTOR_LENGTH; i++) begin
            output_buffer[i] <= 0;
        end
    end else if (rx_state == RX_DONE) begin
        for (i = 0; i < OUTPUT_VECTOR_LENGTH; i++) begin
            output_buffer[i] <= bias_memory[i]; // Start with bias

            for (j = 0; j < INPUT_VECTOR_LENGTH; j++) begin
                if (j < INPUT_VECTOR_LENGTH && i < OUTPUT_VECTOR_LENGTH) begin
                    output_buffer[i] <= output_buffer[i] + (input_buffer[j] * weight_memory[i][j]);
                end
            end

            if (relu && output_buffer[i] < 0) begin
                output_buffer[i] <= 0;
            end

            if (INDUCE_FAILURE_DENSE && !$is_synthesis) begin
                if ($urandom_range(0, 99) == 5) begin
                    output_buffer[i] <= $urandom_range(0, 1023);
                end
            end
        end
    end
end

//-------------------------------------------------------------------//
// Output State Machine
//-------------------------------------------------------------------//
always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
        output_index <= 0;
        tx_state <= TX_IDLE;
    end else begin
        tx_state <= next_tx_state;

        if (features_out.valid && features_out.ready) begin
            if (output_index + 1 < OUTPUT_VECTOR_LENGTH)
                output_index <= output_index + 1;
            else
                output_index <= 0;
        end
    end
end

always_comb begin
    case (tx_state)
        TX_IDLE: next_tx_state = (send) ? TX_SEND : TX_IDLE;
        TX_SEND: next_tx_state = (output_index == OUTPUT_VECTOR_LENGTH - 1) ? TX_DONE : TX_SEND;
        TX_DONE: next_tx_state = TX_IDLE;
        default: next_tx_state = TX_IDLE;
    endcase
end

assign features_out.valid = (tx_state == TX_SEND);
assign features_out.features[0] = (output_index < OUTPUT_VECTOR_LENGTH) ? output_buffer[output_index] : 0;

//-------------------------------------------------------------------//
// Input-Output Behavioral Control
//-------------------------------------------------------------------//
initial begin
    send = 0;
    receive = 0;

    @(posedge reset_n);
    forever begin
        // Input Handling
        receive = 1;
        @(posedge clock);
        receive = 0;
        while (rx_state != RX_DONE) @(posedge clock);

        // Output Handling
        send = 1;
        @(posedge clock);
        send = 0;
        while (tx_state != TX_DONE) @(posedge clock);
    end
end

endmodule : dense
