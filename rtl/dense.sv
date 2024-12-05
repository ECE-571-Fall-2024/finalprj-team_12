
import mnist_pkg::*; 

module dense #(
   parameter INPUT_VECTOR_LENGTH = 784,   // Example: 28x28 image
   parameter OUTPUT_VECTOR_LENGTH = 128, // Output neurons
   parameter load_weights = 1,
   parameter PAR_COMPS = 1,
   parameter weight_file = "dense_weights.hex",
   parameter bias_file = "dense_biases.hex",
   parameter INDUCE_FAILURE_DENSE = 0,    // Parameter to enable induced failure
   parameter relu = 1
)(
   input logic clock,
   input logic reset_n,

   feature_if features_in,
   feature_if features_out
);

   // Define memory sizes and types
   typedef weight_type [INPUT_VECTOR_LENGTH] weight_type;
   typedef feature_type [INPUT_VECTOR_LENGTH] input_type;
   typedef feature_type [OUTPUT_VECTOR_LENGTH] output_type; 
   
   typedef feature_type [INPUT_VECTOR_LENGTH-1:0] input_vector_type;
   typedef feature_type [OUTPUT_VECTOR_LENGTH-1:0] output_vector_type;

   input_vector_type input_buffer;
   output_vector_type output_buffer;

   feature_type weight_memory[OUTPUT_VECTOR_LENGTH][INPUT_VECTOR_LENGTH]; // Weight memory for each output neuron
   feature_type bias_memory[OUTPUT_VECTOR_LENGTH]; // Bias memory for each output neuron

   logic [$clog2(INPUT_VECTOR_LENGTH)-1:0] input_index;
   logic [$clog2(OUTPUT_VECTOR_LENGTH)-1:0] output_index;

   logic start_receive, receiving, done_receive;
   logic start_process, processing, done_process;
   logic start_send, sending, done_send;

   typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
   typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;

   rx_state_type rx_state, next_rx_state;
   tx_state_type tx_state, next_tx_state;

   //--------------------------------------------------------------------
   // Input State Machine
   //--------------------------------------------------------------------
   always_ff @(posedge clock or negedge reset_n) begin
       if (!reset_n) begin
           input_index <= 0;
           input_buffer <= '{default: 0};
           rx_state <= RX_IDLE;
       end else begin
           rx_state <= next_rx_state;

           if (features_in.valid && features_in.ready) begin
               input_buffer[input_index] <= features_in.features[0];
               if (input_index + 1 < INPUT_VECTOR_LENGTH)
                   input_index <= input_index + 1;
               else
                   input_index <= 0;
           end
       end
   end

   always_comb begin
       case (rx_state)
           RX_IDLE: next_rx_state = (features_in.valid) ? RX_RECV : RX_IDLE;
           RX_RECV: next_rx_state = (input_index == INPUT_VECTOR_LENGTH - 1) ? RX_DONE : RX_RECV;
           RX_DONE: next_rx_state = RX_IDLE;
           default: next_rx_state = RX_IDLE;
       endcase
   end

   assign features_in.ready = (rx_state == RX_RECV);

   //--------------------------------------------------------------------
   // Dense Layer Computation with Induced Failure
   //--------------------------------------------------------------------
   integer i, j;
   always_ff @(posedge clock or negedge reset_n) begin
       if (!reset_n) begin
           output_buffer <= '{default: 0};
       end else if (done_receive) begin
           for (i = 0; i < OUTPUT_VECTOR_LENGTH; i++) begin
               output_buffer[i] <= bias_memory[i];
               for (j = 0; j < INPUT_VECTOR_LENGTH; j++) begin
                   output_buffer[i] <= output_buffer[i] + (input_buffer[j] * weight_memory[i][j]);
               end
               if (relu && output_buffer[i] < 0)
                   output_buffer[i] <= 0;

               // Induce failure with 1% probability
               if (INDUCE_FAILURE_DENSE) if ($urandom_range(0, 99) == 5) begin
                   output_buffer[i] <= $urandom_range(0, 1023);
                   $display("[ERROR] Induced failure in dense layer at index %0d: Corrupt value = %0d", i, output_buffer[i]);
               end
           end
       end
   end

   //--------------------------------------------------------------------
   // Output State Machine
   //--------------------------------------------------------------------
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
           TX_IDLE: next_tx_state = (done_process) ? TX_SEND : TX_IDLE;
           TX_SEND: next_tx_state = (output_index == OUTPUT_VECTOR_LENGTH - 1) ? TX_DONE : TX_SEND;
           TX_DONE: next_tx_state = TX_IDLE;
           default: next_tx_state = TX_IDLE;
       endcase
   end

   assign features_out.valid = (tx_state == TX_SEND);
   assign features_out.features[0] = (features_out.valid) ? output_buffer[output_index] : '{default: 0};

endmodule : dense
