
import mnist_pkg::*;

module softmax (
    input  logic          clock,
    input  logic          reset_n,

    feature_if            features_in,
    feature_if            features_out);

//----------------------------------------------------------------//

    feature_type          image[10];
    feature_type          output_image[10];

    logic [3:0]           in_index;
    logic [3:0]           out_index;

    logic send, receive;

    int raw_predictions[10], predictions[10];

    typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
    typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;
    rx_state_type rx_state, next_rx_state;
    tx_state_type tx_state, next_tx_state;

    import "DPI-C" function void softmax(input int vector_in[10], output int vector[10]);

    // --------------------------------------------------------------------
    // process for reading input to image array
    // --------------------------------------------------------------------
 
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

    // --------------------------------------------------------------------
    // state machine for reading in features
    // --------------------------------------------------------------------

    always_comb begin
      case (rx_state)
        RX_IDLE : if (receive) next_rx_state = RX_RECV;
        RX_RECV : if (in_index == 9) next_rx_state = RX_DONE;
        RX_DONE : next_rx_state = RX_IDLE;
        default : next_rx_state = RX_IDLE;
      endcase
    end

    always @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) rx_state = RX_IDLE;
      else rx_state = next_rx_state;
    end

    assign features_in.ready = rx_state == RX_RECV;

    // --------------------------------------------------------------------
    // process for write output from output array
    // --------------------------------------------------------------------
 
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

    // --------------------------------------------------------------------
    // state machine for sending results
    // --------------------------------------------------------------------
 
    always_comb begin
      case (tx_state)
        TX_IDLE : if (send) next_tx_state = TX_SEND;
        TX_SEND : if (out_index == 9) next_tx_state = TX_DONE;
        TX_DONE : next_tx_state = TX_IDLE;
        default : next_tx_state = TX_IDLE;
      endcase
    end

    always @(posedge clock, negedge reset_n) begin
      if (reset_n == 0) tx_state = TX_IDLE;
      else tx_state = next_tx_state;
    end

    assign features_out.valid = tx_state == TX_SEND;

    // --------------------------------------------------------------------
    // interface to C function for computing max-pool
    // --------------------------------------------------------------------

    initial begin
      send = 0;
      receive = 0;

      @(posedge reset_n);
      @(posedge clock);

      forever begin

        // get inputs
        receive = 1;
        @(posedge clock);
        receive = 0;
        while (rx_state != RX_DONE) @(posedge clock);
        @(posedge clock);


        // convert features to int 
        for (int i=0; i<10; i++) begin
          raw_predictions[i] = image[i];
        end

        // call C code
        softmax(raw_predictions, predictions);
  
        // convert ints to features
        for (int i=0; i<10; i++) begin
          output_image[i] = predictions[i];
        end
  
        // send results
        send = 1;
        @(posedge clock);
        send = 0;
        while (tx_state != TX_DONE) @(posedge clock);
        @(posedge clock);
      end
    end

endmodule : softmax
