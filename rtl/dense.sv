
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

    logic [$clog2(INPUT_VECTOR_LENGTH):0]   in_index,  index;
    logic [$clog2(OUTPUT_VECTOR_LENGTH):0]  out_index, sum_index;

    logic send, receive;

    typedef enum logic [1:0] {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
    typedef enum logic [1:0] {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;
    typedef enum logic [1:0] {ST_IDLE, ST_RECV, ST_PROCESS, ST_SEND} st_state_type;

    rx_state_type rx_state, next_rx_state;
    tx_state_type tx_state, next_tx_state;
    st_state_type st_state, next_st_state;

    // load weight and bias memories

    initial $readmemh(weight_file, weight_memory);
    initial $readmemh(bias_file, bias_memory);

    // --------------------------------------------------------------
    // process for reading features into image array
    // --------------------------------------------------------------

    always_ff @(posedge clock, negedge reset_n) begin
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

    always_ff @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) rx_state = RX_IDLE;
      else rx_state = next_rx_state;
    end

    assign features_in.ready = rx_state == RX_RECV;

    // --------------------------------------------------------------
    // process for reading features into image array
    // --------------------------------------------------------------

    always_ff @(posedge clock, negedge reset_n) begin
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

    always_ff @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) tx_state = TX_IDLE;
      else tx_state = next_tx_state;
    end

    assign features_out.valid = tx_state == TX_SEND;

    always_comb begin
      case (st_state)
        ST_IDLE : next_st_state = ST_RECV;
        ST_RECV : if (rx_state == RX_DONE) next_st_state = ST_PROCESS;
        ST_PROCESS : if ((index + 1     >= INPUT_VECTOR_LENGTH) &&
                         (sum_index + 1 >= OUTPUT_VECTOR_LENGTH)) next_st_state = ST_SEND;
        ST_SEND : if (tx_state == TX_DONE) next_st_state = ST_IDLE;
        default : next_st_state = ST_IDLE;
      endcase
    end

    always_ff @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) st_state = ST_IDLE;
      else st_state = next_st_state;
    end

    assign receive = st_state == ST_RECV;
    assign prcs    = st_state == ST_PROCESS;
    assign send    = st_state == ST_SEND;

    always_ff @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) begin
        index     <= '0;
        sum_index <= '0;
        sum       <= '0;
      end else begin
        if (receive) begin
          sum       <= bias_memory[0];
          index     <= 0;
          sum_index <= 0;
        end
        if (prcs) begin
 
          sum <= sum + ((image[index] * weight_memory[sum_index * INPUT_VECTOR_LENGTH + index]) >>> weight_frac_bits);

          if ((index + 1) < INPUT_VECTOR_LENGTH) index <= index + 1;
          else begin
            index <= 0;
            sum <= bias_memory[sum_index + 1];
            output_image[sum_index] <= sum;
            if ((sum_index + 1) < OUTPUT_VECTOR_LENGTH) sum_index <= sum_index + 1;
          end
        end
      end
    end

endmodule : dense
