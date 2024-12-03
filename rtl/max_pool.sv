import mnist_pkg::feature_type;

module max_pool #(
    parameter int ROW_STRIDE    =  2,
              int COL_STRIDE    =  2,
              int IMAGE_HEIGHT  = 28,
              int IMAGE_WIDTH   = 28
 )(
   input logic         clock,
   input logic         reset_n,

   feature_if          features_in,
   feature_if          features_out);

//--------------------------------------------------------------------------------//

   feature_type        image[IMAGE_HEIGHT][IMAGE_WIDTH];
   feature_type        image_out[IMAGE_HEIGHT/ROW_STRIDE][IMAGE_WIDTH/COL_STRIDE];
   feature_type        max;
   feature_type        f;

   logic [$clog2(IMAGE_HEIGHT):0]  in_row;
   logic [$clog2(IMAGE_WIDTH):0]   in_col;
   logic [$clog2(IMAGE_HEIGHT):0]  out_row;
   logic [$clog2(IMAGE_WIDTH):0]   out_col;

   logic send, receive;

   typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
   typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;
   rx_state_type rx_state, next_rx_state;
   tx_state_type tx_state, next_tx_state;

   // -------------------------------------------------------------------------
   // print functions for input and output images 
   // -------------------------------------------------------------------------

   function automatic void print_image(ref feature_type image[IMAGE_HEIGHT][IMAGE_WIDTH]);
     for (int r=0; r<IMAGE_HEIGHT; r++) begin
       for (int c=0; c<IMAGE_WIDTH; c++) begin
         if (image[r][c]) $write("%4x ", image[r][c]); else $write("     ");
       end
       $write("\n");
     end
   endfunction

   function automatic void print_out_image(ref feature_type image[IMAGE_HEIGHT/ROW_STRIDE][IMAGE_WIDTH/COL_STRIDE]);
     for (int r=0; r<IMAGE_HEIGHT/ROW_STRIDE; r++) begin
       for (int c=0; c<IMAGE_WIDTH/COL_STRIDE; c++) begin
         if (image[r][c]) $write("%4x ", image[r][c]); else $write("     ");
       end
       $write("\n");
     end
   endfunction

   // -------------------------------------------------------------------------
   // process for reading in features into image array 
   // -------------------------------------------------------------------------

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       in_row       <= '0;
       in_col       <= '0;
     end else begin
       if (features_in.valid & features_in.ready) begin
         image[in_row][in_col] <= features_in.features[0];
         if ((in_col + 1) < IMAGE_WIDTH) begin
           in_col <= in_col + 1;
         end else begin
           in_col <= 0;
           in_row <= in_row + 1;
         end
       end
       if (rx_state == RX_DONE) begin
         in_row <= '0;
         in_col <= '0;
       end
     end
   end

   // -------------------------------------------------------------------------
   // state machine for reading in features
   // -------------------------------------------------------------------------

   always_comb begin
     case (rx_state)
       RX_IDLE : if (receive) next_rx_state = RX_RECV;
       RX_RECV : if ((in_row == IMAGE_HEIGHT - 1) &&
                     (in_col == IMAGE_WIDTH  - 1)) next_rx_state = RX_DONE;
       RX_DONE : next_rx_state = RX_IDLE;
       default : next_rx_state = RX_IDLE;
     endcase
   end

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) rx_state = RX_IDLE;
     else rx_state = next_rx_state;
   end

   assign features_in.ready = rx_state == RX_RECV;

   // -------------------------------------------------------------------------
   // process for writing out features from image_out array
   // -------------------------------------------------------------------------

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       out_row <= '0;
       out_col <= '0;
     end else begin
       if (features_out.valid & features_out.ready) begin
         if ((out_col + 1) < IMAGE_HEIGHT/ROW_STRIDE) begin
           out_col <= out_col + 1;
         end else begin
           out_col <= 0;
           out_row <= out_row + 1;
         end
       end
       if (tx_state == TX_DONE) begin
         out_row <= '0; 
         out_col <= '0;
       end
     end
   end

   assign features_out.features[0] = image_out[out_row][out_col];

   // -------------------------------------------------------------------------
   // state machine for writing out features
   // -------------------------------------------------------------------------

   always_comb begin
     case (tx_state)
       TX_IDLE : if (send) next_tx_state = TX_SEND;
       TX_SEND : if ((out_row == IMAGE_HEIGHT/ROW_STRIDE - 1) &&
                     (out_col == IMAGE_WIDTH/COL_STRIDE - 1)) next_tx_state = TX_DONE;
       TX_DONE : next_tx_state = TX_IDLE;
       default : next_tx_state = TX_IDLE;
     endcase
   end

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) tx_state = TX_IDLE;
     else tx_state = next_tx_state;
   end

   assign features_out.valid = tx_state == TX_SEND;

   // -------------------------------------------------------------------------
   // max pool logic
   // -------------------------------------------------------------------------

  always_ff @(posedge clock or negedge reset_n) begin
     if (!reset_n) begin
    	send <= 0;
    	receive <= 1;
     end else if (rx_state == RX_DONE) begin
    	receive <= 0;
    
	// Process max pooling after receiving data
    for (int row = 0; row < IMAGE_HEIGHT; row += ROW_STRIDE) begin
      for (int col = 0; col < IMAGE_WIDTH; col += COL_STRIDE) begin
        max = image[row][col];  // Initialize max
        for (int r = 0; r < ROW_STRIDE; r++) begin
          for (int c = 0; c < COL_STRIDE; c++) begin
            if (image[row + r][col + c] > max)
              max = image[row + r][col + c];
          end
        end
        image_out[row/ROW_STRIDE][col/COL_STRIDE] <= max; // Store the max value
      end
    end
      send <= 1;  // Trigger sending the result
      end else if (tx_state == TX_DONE) begin
      send <= 0;
      receive <= 1;  // Prepare to receive the next image
  end
end
   
endmodule : max_pool