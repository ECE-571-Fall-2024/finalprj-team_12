
import mnist_pkg::*;

module convolution #(
   parameter IMAGE_HEIGHT  = 28,
   parameter IMAGE_WIDTH   = 28,
   parameter FILTER_HEIGHT =  5,
   parameter FILTER_WIDTH  =  5,
   parameter input_images  =  1,
   parameter output_images = 20,
   parameter load_weights  =  1,
   parameter weight_file   = "weights.hex",
   parameter bias_file     = "biases.hex"
 )(
   input logic         clock,
   input logic         reset_n,

   feature_if          features_in,
   feature_if          features_out);

//----------------------------------------------------------------//

   typedef weight_type [FILTER_WIDTH][FILTER_HEIGHT] filter_type;

   weight_type   bias_memory[output_images];
   filter_type   weight_memory [output_images][input_images];
   feature_type  output_buffer [IMAGE_HEIGHT][IMAGE_WIDTH], images [input_images][IMAGE_HEIGHT][IMAGE_WIDTH];
   sum_type      sum, factor_1, factor_2, product;
   int           r, c;

   logic [$clog2(IMAGE_HEIGHT):0]  in_row;
   logic [$clog2(IMAGE_WIDTH):0]   in_col;
   logic [$clog2(input_images):0]  in_image_no;
   logic [$clog2(IMAGE_HEIGHT):0]  out_row;
   logic [$clog2(IMAGE_WIDTH):0]   out_col;
   logic [$clog2(output_images):0] out_image_no;

   // load weight and bias memories

   initial begin
     if (load_weights) begin
       $readmemh(weight_file, weight_memory);
       $readmemh(bias_file, bias_memory);
     end
   end

   // helper funcitons

   function automatic void print_image(ref feature_type image[IMAGE_HEIGHT][IMAGE_WIDTH]);
     for (int r=0; r<IMAGE_HEIGHT; r++) begin
       for (int c=0; c<IMAGE_WIDTH; c++) begin
         if (image[r][c]) $write("%4x ", image[r][c]); else $write("     ");
       end
       $write("\n");
     end
   endfunction 

   function automatic void print_filter(ref filter_type fltr);
     for (int r=0; r<FILTER_HEIGHT; r++) begin
       for (int c=0; c<FILTER_WIDTH; c++) begin
         $write("%4x ", fltr[r][c]);
       end
       $write("\n");
     end
   endfunction 

   function automatic logic in_bounds(int r, int c);
     return ((r >= 0) && (r < IMAGE_HEIGHT) && (c >= 0) && (c < IMAGE_WIDTH));
   endfunction

   // signals, enums for input and output state machines

   logic send, receive;
   logic image_loaded, image_sent;

   typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
   typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;
   rx_state_type rx_state, next_rx_state;
   tx_state_type tx_state, next_tx_state;

   // feature_type f;

   // --------------------------------------------------------------------
   // process to load features into image array
   // --------------------------------------------------------------------

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       in_row      <= '0; 
       in_col      <= '0;
       in_image_no <= '0;
     end else begin
       if (features_in.ready && features_in.valid) begin
         images[in_image_no][in_row][in_col] = features_in.features[0];
         if ((in_col + 1) < IMAGE_WIDTH) begin
           in_col <= in_col + 1;
         end else begin
           in_col <= '0;
           if ((in_row + 1) < IMAGE_HEIGHT) begin
             in_row <= in_row + 1;
           end else begin
             in_row <= '0;
             in_image_no <= in_image_no + 1;
           end
         end
       end
       if (rx_state == RX_DONE) begin
         in_row      <= 0;
         in_col      <= 0;
         in_image_no <= 0;
       end
     end
   end

   // --------------------------------------------------------------------
   // state machine to read in features
   // --------------------------------------------------------------------

   always_comb begin
     case (rx_state)
       RX_IDLE : if (receive) next_rx_state = RX_RECV;
       RX_RECV : if ((in_row == IMAGE_HEIGHT - 1) && 
                  (in_col == IMAGE_WIDTH - 1)  &&
                  (in_image_no == input_images - 1)) next_rx_state = RX_DONE;
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
   // process to write out processed image
   // --------------------------------------------------------------------

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       out_row <= '0;
       out_col <= '0;
     end else begin
       if (features_out.valid && features_out.ready) begin
         out_col <= ((out_col + 1) == IMAGE_WIDTH) ? 0 : out_col + 1;
         if ((out_col + 1) < IMAGE_WIDTH) begin
           out_col <= out_col + 1;
         end else begin
           out_col <= 0;
           out_row <= out_row + 1;
         end
       end
       if (tx_state != TX_SEND) begin
         out_row <= '0;
         out_col <= '0;
       end
     end
   end

   // --------------------------------------------------------------------
   // state machine to write out features
   // --------------------------------------------------------------------

   always_comb begin
     case (tx_state)
       TX_IDLE : if (send) next_tx_state = TX_SEND;
       TX_SEND : if ((out_row == IMAGE_HEIGHT-1) && 
                  (out_col == IMAGE_WIDTH-1)) next_tx_state = TX_DONE;
       TX_DONE : next_tx_state = TX_IDLE;
       default : next_tx_state = TX_IDLE;
     endcase
   end

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) tx_state = TX_IDLE;
     else tx_state = next_tx_state;
   end

   assign features_out.valid = tx_state == TX_SEND;
   assign features_out.features[0] = output_buffer[out_row][out_col];

   // --------------------------------------------------------------------
   // behavioral code to perform convolution - todo: make real hardware for this
   // --------------------------------------------------------------------

   initial begin
     send = 0;
     receive = 0;
     @(posedge reset_n);
     @(posedge clock);
     forever begin

       receive = 1;
       @(posedge clock);
       receive = 0;
       while (rx_state != RX_DONE) @(posedge clock);
       @(posedge clock);

       for (int o=0; o<output_images; o++) begin
         for (int i=0; i<input_images; i++) begin
           for (int row=0; row<IMAGE_WIDTH; row++) begin
             for (int col=0; col<IMAGE_HEIGHT; col++) begin
               sum = 0;
               for (int fr=0; fr<FILTER_WIDTH; fr++) begin
                 for (int fc=0; fc<FILTER_HEIGHT; fc++) begin
                   r = row - ((FILTER_HEIGHT-1)/2) + fr;
                   c = col - ((FILTER_WIDTH-1)/2) + fc;
                   factor_1 = images[i][r][c];
                   factor_2 = weight_memory[o][i][fr][fc];
                   product = (factor_1 * factor_2) >>> 8;
                   if (in_bounds(r, c)) sum += product; 
                 end
               end
               output_buffer[row][col] = (i==0) ? sum + bias_memory[o] : sum + output_buffer[row][col];
               if ((i+1) == input_images) if (output_buffer[row][col]<0) output_buffer[row][col] = '0;
             end
           end
         end

         send = 1;
         @(posedge clock);
         send = 0;
         while (tx_state != TX_DONE) @(posedge clock);
         @(posedge clock);

       end
     end
   end

endmodule : convolution
