import mnist_pkg::*;

module dense #(
    parameter INPUT_VECTOR_LENGTH  = 100,
              OUTPUT_VECTOR_LENGTH = 100,
              NUM_FEATURES         = 2,   // Number of features processed per cycle
              relu                 = 1,
              weight_file,
              bias_file
  )( 
    input  logic          clock,
    input  logic          reset_n,

    feature_if            features_in,
    feature_if            features_out);

//-------------------------------------------------------------------//
// Internal signals
//-------------------------------------------------------------------//

    logic  [$clog2(INPUT_VECTOR_LENGTH)-1:0]  feature_in_count;
    logic  [$clog2(OUTPUT_VECTOR_LENGTH)-1:0] feature_out_count;

    feature_type          image[INPUT_VECTOR_LENGTH];
    feature_type          output_image[OUTPUT_VECTOR_LENGTH];

    feature_type          feature[NUM_FEATURES];
    sum_type              sum[NUM_FEATURES];

    weight_type weight_memory[OUTPUT_VECTOR_LENGTH * INPUT_VECTOR_LENGTH];
    weight_type bias_memory[OUTPUT_VECTOR_LENGTH];

    logic [$clog2(INPUT_VECTOR_LENGTH):0]   in_index;
    logic [$clog2(OUTPUT_VECTOR_LENGTH):0]  out_index;

    logic send, receive;

    typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
    typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;
    rx_state_type rx_state, next_rx_state;
    tx_state_type tx_state, next_tx_state;

    // State for computation
    typedef enum {COMPUTE_IDLE, COMPUTE_BUSY, COMPUTE_DONE} compute_state_type;
    compute_state_type compute_state, next_compute_state;

    logic [$clog2(OUTPUT_VECTOR_LENGTH)-1:0] o_counter;
    logic [$clog2(INPUT_VECTOR_LENGTH)-1:0] i_counter;

    logic compute;

    // Load weight and bias memories
    initial $readmemh(weight_file, weight_memory);
    initial $readmemh(bias_file, bias_memory);

//-------------------------------------------------------------------//
// Reading features into image array
//-------------------------------------------------------------------//

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n)
            in_index <= '0;
        else if (features_in.valid & features_in.ready) begin
            for (int i = 0; i < NUM_FEATURES; i++) begin
                if (in_index + i < INPUT_VECTOR_LENGTH)
                    image[in_index + i] <= features_in.features[i];
            end
            in_index <= in_index + NUM_FEATURES;
        end
        if (rx_state == RX_DONE)
            in_index <= '0;
    end

// Reading State Machine
    always_comb begin
        case (rx_state)
            RX_IDLE: if (receive) next_rx_state = RX_RECV;
            RX_RECV: if (in_index >= INPUT_VECTOR_LENGTH - NUM_FEATURES) next_rx_state = RX_DONE;
            RX_DONE: next_rx_state = RX_IDLE;
            default: next_rx_state = RX_IDLE;
        endcase
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n)
            rx_state <= RX_IDLE;
        else
            rx_state <= next_rx_state;
    end

    assign features_in.ready = (rx_state == RX_RECV);

//-------------------------------------------------------------------//
// Writing results to output
//-------------------------------------------------------------------//

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n)
            out_index <= '0;
        else if (features_out.valid & features_out.ready)
            out_index <= out_index + NUM_FEATURES;
        if (tx_state == TX_DONE)
            out_index <= '0;
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (tx_state == TX_SEND) begin
            for (int i = 0; i < NUM_FEATURES; i++) begin
                if (out_index + i < OUTPUT_VECTOR_LENGTH)
                    features_out.features[i] <= output_image[out_index + i];
            end
        end
    end

    always_comb begin
        case (tx_state)
            TX_IDLE: if (send) next_tx_state = TX_SEND;
            TX_SEND: if (out_index >= OUTPUT_VECTOR_LENGTH - NUM_FEATURES) next_tx_state = TX_DONE;
            TX_DONE: next_tx_state = TX_IDLE;
            default: next_tx_state = TX_IDLE;
        endcase
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n)
            tx_state <= TX_IDLE;
        else
            tx_state <= next_tx_state;
    end

    assign features_out.valid = (tx_state == TX_SEND);

//-------------------------------------------------------------------//
// Dense computation logic
//-------------------------------------------------------------------//

    always_comb begin
        case (compute_state)
            COMPUTE_IDLE: if (rx_state == RX_DONE) next_compute_state = COMPUTE_BUSY;
            COMPUTE_BUSY: if ((o_counter >= OUTPUT_VECTOR_LENGTH - NUM_FEATURES) && 
                              (i_counter >= INPUT_VECTOR_LENGTH - 1)) next_compute_state = COMPUTE_DONE;
            COMPUTE_DONE: next_compute_state = COMPUTE_IDLE;
            default: next_compute_state = COMPUTE_IDLE;
        endcase
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n)
            compute_state <= COMPUTE_IDLE;
        else
            compute_state <= next_compute_state;
    end

    assign compute = (compute_state == COMPUTE_BUSY);

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            o_counter <= '0;
            i_counter <= '0;
        end else if (compute) begin
            if (i_counter < INPUT_VECTOR_LENGTH - 1)
                i_counter <= i_counter + 1;
            else begin
                i_counter <= '0;
                if (o_counter < OUTPUT_VECTOR_LENGTH - NUM_FEATURES)
                    o_counter <= o_counter + NUM_FEATURES;
            end
        end else if (compute_state == COMPUTE_IDLE) begin
            o_counter <= '0;
            i_counter <= '0;
        end
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            for (int i = 0; i < NUM_FEATURES; i++) sum[i] <= '0;
        end else if (compute) begin
            for (int i = 0; i < NUM_FEATURES; i++) begin
                if (i_counter == '0)
                    sum[i] <= bias_memory[o_counter + i];
                sum[i] <= sum[i] + 
                          ((image[i_counter] * weight_memory[(o_counter + i) * INPUT_VECTOR_LENGTH + i_counter]) 
                          >>> mnist_pkg::weight_frac_bits);
            end
        end else if (compute_state == COMPUTE_DONE) begin
            for (int i = 0; i < NUM_FEATURES; i++) begin
                if (relu)
                    output_image[o_counter + i] <= (sum[i] > 0) ? sum[i] : 0;
                else
                    output_image[o_counter + i] <= sum[i];
            end
        end
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n)
            send <= 0;
        else if (compute_state == COMPUTE_DONE)
            send <= 1;
        else
            send <= 0;
    end

endmodule : dense

