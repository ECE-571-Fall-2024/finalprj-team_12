
import mnist_pkg::*;

module dense #(
    parameter INPUT_VECTOR_LENGTH  = 100,
              OUTPUT_VECTOR_LENGTH = 100,
              relu                 = 1,
              weight_file,
              bias_file
  )( 
    input  logic          clock,
    input  logic          reset_n,

    feature_if            features_in,
    feature_if            features_out);

//-------------------------------------------------------------------//

    logic  [$clog2(INPUT_VECTOR_LENGTH)-1:0]  feature_in_count;
    logic  [$clog2(OUTPUT_VECTOR_LENGTH)-1:0] feature_out_count;

    feature_type          image[INPUT_VECTOR_LENGTH];
    feature_type          output_image[OUTPUT_VECTOR_LENGTH];

    feature_type          feature;
    feature_type          f;
    sum_type              sum;

    weight_type weight_memory[OUTPUT_VECTOR_LENGTH * INPUT_VECTOR_LENGTH];
    weight_type bias_memory[OUTPUT_VECTOR_LENGTH];

    logic [$clog2(INPUT_VECTOR_LENGTH):0]   in_index;
    logic [$clog2(OUTPUT_VECTOR_LENGTH):0]  out_index;

    logic send, receive;

    typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
    typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;
    rx_state_type rx_state, next_rx_state;
    tx_state_type tx_state, next_tx_state;

    // load weight and bias memories

    initial $readmemh(weight_file, weight_memory);
    initial $readmemh(bias_file, bias_memory);

    // --------------------------------------------------------------
    // process for reading features into image array
    // --------------------------------------------------------------

    always @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) in_index     <= '0;
      else begin
        if (features_in.valid & features_in.ready) begin
          image[in_index] <= features_in.features[0];
          in_index <= in_index + 1;
        end
        if (rx_state == RX_DONE) in_index <= '0;
      end
    end

    // --------------------------------------------------------------
    // state machine for reading in features
    // --------------------------------------------------------------

    always_comb begin
      case (rx_state)
        RX_IDLE : if (receive) next_rx_state = RX_RECV;
        RX_RECV : if (in_index == INPUT_VECTOR_LENGTH - 1) next_rx_state = RX_DONE;
        RX_DONE : next_rx_state = RX_IDLE;
        default : next_rx_state = RX_IDLE;
      endcase
    end

    always @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) rx_state = RX_IDLE;
      else rx_state = next_rx_state;
    end

    assign features_in.ready = rx_state == RX_RECV;

    // --------------------------------------------------------------
    // process for outputting results
    // --------------------------------------------------------------

    always @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) out_index <= '0;
      else begin
        if (features_out.valid & features_out.ready) begin
          out_index <= out_index + 1;
        end
        if (tx_state == TX_DONE) out_index <= '0;
      end
    end

    assign features_out.features[0] = output_image[out_index];

    // --------------------------------------------------------------
    // state machine for writing out results
    // --------------------------------------------------------------

    always_comb begin
      case (tx_state)
        TX_IDLE : if (send) next_tx_state = TX_SEND;
        TX_SEND : if (out_index == OUTPUT_VECTOR_LENGTH-1) next_tx_state = TX_DONE;
        TX_DONE : next_tx_state = TX_IDLE;
        default : next_tx_state = TX_IDLE;
      endcase
    end

    always @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) tx_state = TX_IDLE;
      else tx_state = next_tx_state;
    end

    assign features_out.valid = tx_state == TX_SEND;

    // --------------------------------------------------------------
    // control signals for dense computation
    // --------------------------------------------------------------

    logic compute;
    typedef enum {COMPUTE_IDLE, COMPUTE_BUSY, COMPUTE_DONE} compute_state_type;
    compute_state_type compute_state, next_compute_state;
    logic [$clog2(OUTPUT_VECTOR_LENGTH)-1:0] o_counter;
    logic [$clog2(INPUT_VECTOR_LENGTH)-1:0] i_counter;

    always_comb begin
      case (compute_state)
        COMPUTE_IDLE: if (rx_state == RX_DONE) next_compute_state = COMPUTE_BUSY;
        COMPUTE_BUSY: if ((o_counter == OUTPUT_VECTOR_LENGTH-1) && (i_counter == INPUT_VECTOR_LENGTH-1))
                        next_compute_state = COMPUTE_DONE;
        COMPUTE_DONE: next_compute_state = COMPUTE_IDLE;
        default: next_compute_state = COMPUTE_IDLE;
      endcase
    end

    always @(posedge clock, negedge reset_n) begin
      if (!reset_n) compute_state <= COMPUTE_IDLE;
      else compute_state <= next_compute_state;
    end

    assign compute = compute_state == COMPUTE_BUSY;

    // --------------------------------------------------------------
    // control counters for dense computation
    // --------------------------------------------------------------

    always @(posedge clock, negedge reset_n) begin
      if (!reset_n) begin
        o_counter <= '0;
        i_counter <= '0;
      end else if (compute) begin
        if (i_counter < INPUT_VECTOR_LENGTH-1) begin
          i_counter <= i_counter + 1;
        end else begin
          i_counter <= '0;
          if (o_counter < OUTPUT_VECTOR_LENGTH-1) begin
            o_counter <= o_counter + 1;
          end
        end
      end else if (compute_state == COMPUTE_IDLE) begin
        o_counter <= '0;
        i_counter <= '0;
      end
    end

    // --------------------------------------------------------------
    // dense computation logic
    // --------------------------------------------------------------

    always @(posedge clock, negedge reset_n) begin
      if (!reset_n) begin
        sum <= '0;
      end else if (compute) begin
        if (i_counter == '0) sum <= bias_memory[o_counter];
        sum <= sum + (image[i_counter] * weight_memory[o_counter * INPUT_VECTOR_LENGTH + i_counter]) >>> 8;
      end else if (compute_state == COMPUTE_DONE) begin
        if (relu) 
          output_image[o_counter] <= (sum > 0) ? sum : 0;
        else
          output_image[o_counter] <= sum;
      end
    end

    // --------------------------------------------------------------
    // trigger send signal after computation is complete
    // --------------------------------------------------------------

    always @(posedge clock, negedge reset_n) begin
      if (!reset_n) send <= 0;
      else if (compute_state == COMPUTE_DONE) send <= 1;
      else send <= 0;
    end

endmodule : dense
