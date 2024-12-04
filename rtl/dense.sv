
import mnist_pkg::*; 

module dense #(
   parameter INPUT_SIZE = 784,   // Example: 28x28 image
   parameter OUTPUT_SIZE = 128,
   //parameter INPUT_VECTOR_SIZE = 784,   // Example: 28x28 image
   //parameter OUTPUT_VECTOR_SIZE = 128,   // Output neurons
   parameter load_weights = 1,
   parameter PAR_COMPS = 1,
   parameter weight_file = "dense_weights.hex",
   parameter bias_file = "dense_biases.hex",
   parameter INDUCE_FAILURE = 0,
   parameter relu = 1
 )(
   input logic clock,
   input logic reset_n,

   feature_if features_in,
   feature_if features_out
);

   // Define memory sizes and types
   typedef weight_type [INPUT_SIZE] weight_type;
   typedef feature_type [INPUT_SIZE] input_type;
   typedef feature_type [OUTPUT_SIZE] output_type; 
   
   typedef feature_type [INPUT_SIZE-1:0] input_vector_type;
   typedef feature_type [OUTPUT_SIZE-1:0] output_vector_type;

   input_vector_type input_buffer;
   output_vector_type output_buffer;

   feature_type weight_memory[OUTPUT_SIZE][INPUT_SIZE]; // Weight memory for each output neuron
   feature_type bias_memory[OUTPUT_SIZE]; // Bias memory for each output neuron

   logic [$clog2(INPUT_SIZE)-1:0] input_index;
   logic [$clog2(OUTPUT_SIZE)-1:0] output_index;

   //logic signed [31:0] sum [OUTPUT_SIZE];
   
   logic start_receive, receiving, done_receive;
   logic start_process, processing, done_process;
   logic start_send, sending, done_send;
   logic receive, send;

   typedef enum {ST_IDLE, ST_RX, ST_RECV, ST_RX_DONE, ST_PROCESS, ST_FLUSH, ST_DONE} st_state_type;
   typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
   typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;

   st_state_type state, next_state;
   rx_state_type rx_state, next_rx_state;
   tx_state_type tx_state, next_tx_state;

   //--------------------------------------------------------------------//
   // Process to load input features
   //--------------------------------------------------------------------//
   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       input_index <= 0;
       input_buffer <= '0;
     end else begin
       if (features_in.ready && features_in.valid) begin
         input_buffer[input_index] <= features_in.features[0];
         if ((input_index + 1) < INPUT_SIZE) 
           input_index <= input_index + 1;
         else 
           input_index <= 0; // Reset after receiving full input
       end
     end
   end

   //--------------------------------------------------------------------//
   // State machine to receive input
   //--------------------------------------------------------------------//
   always_comb begin
     case (rx_state)
       RX_IDLE : if (receive) next_rx_state = RX_RECV;
       RX_RECV : if (input_index == INPUT_SIZE - 1) next_rx_state = RX_DONE;
       RX_DONE : next_rx_state = RX_IDLE;
       default : next_rx_state = RX_IDLE;
     endcase
   end

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) rx_state <= RX_IDLE;
     else rx_state <= next_rx_state;
   end

   assign features_in.ready = rx_state == RX_RECV;

   //--------------------------------------------------------------------//
   // Dense Layer Computation (Multiply-Accumulate for each output neuron)
   //--------------------------------------------------------------------//
   integer i, j;
   logic signed [$clog2(INPUT_SIZE):0] sum;

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       output_buffer <= '0;
     end else begin
       if (processing) begin
         // Reset sum for each output neuron
         for (i = 0; i < OUTPUT_SIZE; i++) begin
           sum[i] <= 0;
           // Perform multiply-accumulate for each input and weight
           for (j = 0; j < INPUT_SIZE; j++) begin
             sum[i] <= sum[i] + (input_buffer[j] * weight_memory[i][j]);
           end
		   if (relu && output_buffer[i] < 0) output_buffer[i] = 0;
           // Add the bias for each output neuron
           sum[i] <= sum[i] + bias_memory[i];
         end
       end
     end
   end

   //--------------------------------------------------------------------//
   // Process to output result
   //--------------------------------------------------------------------//
   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       output_index <= 0;
     end else begin
       if (done_process) begin
         if ((output_index + 1) < OUTPUT_SIZE) 
           output_index <= output_index + 1;
         else 
           output_index <= 0; // Reset after processing all outputs
       end
     end
   end

   //--------------------------------------------------------------------//
   // Output features
   //--------------------------------------------------------------------//
   always_ff @(posedge clock) begin
     if (done_process) begin
       if (output_buffer[output_index] > 0) 
         features_out.features[0] <= output_buffer[output_index];
       else
         features_out.features[0] <= '0; // Set to zero if negative value
     end
   end

   //--------------------------------------------------------------------//
   // State machine for the dense layer computation
   //--------------------------------------------------------------------//
   always_comb begin
     case (state)
       ST_IDLE : next_state = ST_RX;
       ST_RX : next_state = ST_RECV;
       ST_RECV : if (rx_state == RX_DONE) next_state = ST_RX_DONE;
       ST_RX_DONE : next_state = ST_PROCESS;
       ST_PROCESS : if (done_process) next_state = ST_FLUSH;
       ST_FLUSH : next_state = ST_DONE;
       ST_DONE : next_state = ST_IDLE;
       default : next_state = ST_IDLE;
     endcase
   end

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) state <= ST_IDLE;
     else state <= next_state;
   end

   //--------------------------------------------------------------------//
   // Assign control signals
   //--------------------------------------------------------------------//
   assign start_receive = state == ST_RX;
   assign receiving = state == ST_RECV;
   assign done_receive = state == ST_RX_DONE;
   assign start_process = state == ST_PROCESS;
   assign processing = state == ST_PROCESS;
   assign done_process = state == ST_FLUSH;
   assign start_send = state == ST_FLUSH;
   assign sending = state == ST_FLUSH;
   assign done_send = state == ST_DONE;

   assign receive = start_receive;
   assign send = start_send;

endmodule : dense
 
