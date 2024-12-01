
import mnist_pkg::*;

module convolution #(
   parameter IMAGE_HEIGHT  = 28,
   parameter IMAGE_WIDTH   = 28,
   parameter FILTER_HEIGHT =  5,
   parameter FILTER_WIDTH  =  5,
   parameter input_images  =  1,
   parameter output_images = 20,
   parameter load_weights  =  1,
   parameter PAR_COMPS     = 1,
   parameter weight_file   = "weights.hex",
   parameter bias_file     = "biases.hex"
 )(
   input logic         clock,
   input logic         reset_n,

   feature_if          features_in,
   feature_if          features_out);

//----------------------------------------------------------------//

   parameter IMAGE_SIZE          = IMAGE_HEIGHT * IMAGE_WIDTH;
   parameter SHIFT_REGISTER_SIZE = ((FILTER_HEIGHT - 1) * IMAGE_WIDTH) + FILTER_WIDTH + (PAR_COMPS - 1);

   typedef weight_type [FILTER_WIDTH][FILTER_HEIGHT] filter_type;

   weight_type   bias_memory[output_images];
   filter_type   weight_memory [output_images][input_images];
   feature_type  output_buffer [IMAGE_HEIGHT * IMAGE_WIDTH], images [input_images][IMAGE_HEIGHT * IMAGE_WIDTH];
   feature_type  sh_reg[SHIFT_REGISTER_SIZE];
   sum_type      sum, factor_1[FILTER_HEIGHT][FILTER_WIDTH], factor_2[FILTER_HEIGHT][FILTER_WIDTH], product[FILTER_HEIGHT][FILTER_WIDTH];

   logic [$clog2(input_images):0]  in_image_no;
   logic [$clog2(input_images):0]  p_image_no;
   logic [$clog2(output_images):0] out_image_no;

   sum_type                        product_array [PAR_COMPS][FILTER_HEIGHT][FILTER_WIDTH];
   sum_type                        row_sums[PAR_COMPS][FILTER_HEIGHT];
   sum_type                        filter_sums[PAR_COMPS];

   initial begin
    $display("image height: %1d ", IMAGE_HEIGHT);
    $display("image width:  %1d ", IMAGE_WIDTH);
    $display("image size:   %1d ", IMAGE_SIZE);
   end

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

   function automatic void print_shift_register(ref feature_type sr[SHIFT_REGISTER_SIZE]);
     $display("\n\nshift_register: ");
     for (int r=0; r<FILTER_HEIGHT-1; r++) begin
       for (int c=0; c<IMAGE_WIDTH; c++) begin
         $write("%3d ", sr[r*IMAGE_WIDTH+c]);
       end
       $write("\n");
     end
     for (int c=0; c<FILTER_WIDTH; c++) begin
       $write("%3d ", sr[((FILTER_HEIGHT-1)*IMAGE_WIDTH)+c]);
     end
     $write("\n\n");
   endfunction

   function automatic logic in_bounds(int r, int c);
     return ((r >= 0) && (r < IMAGE_HEIGHT) && (c >= 0) && (c < IMAGE_WIDTH));
   endfunction

   // signals, enums for input and output state machines

   logic start_receive, receiving,  done_receive;
   logic start_process, processing, done_process, processing_d1, processing_d2;
   logic start_send,    sending,    done_send;
   logic send, receive;
   logic shifting;
   logic image_loaded, image_sent;

   logic [$clog2(IMAGE_SIZE):0] in_index, out_index, buff_out_index, buff_out_index_d1, buff_out_index_d2;
   logic signed [$clog2(IMAGE_SIZE + 2 * SHIFT_REGISTER_SIZE):0] p_index, head_pixel, zero_pixel, tail_pixel;

   typedef enum {ST_IDLE, ST_RX, ST_RECV, ST_RX_DONE, ST_START, ST_PX, ST_PROCESS, ST_FLUSH, ST_PX_DONE, ST_TX, ST_SEND, ST_TX_DONE, ST_DONE} st_state_type;
   typedef enum {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
   typedef enum {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;

   st_state_type state, next_state;
   rx_state_type rx_state, next_rx_state;
   tx_state_type tx_state, next_tx_state;

   // --------------------------------------------------------------------
   // process to load features into image array
   // --------------------------------------------------------------------

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       in_index    <= '0; 
       in_image_no <= '0;
     end else begin
       if (features_in.ready && features_in.valid) begin
         images[in_image_no][in_index] = features_in.features[0];
         if ((in_index + PAR_COMPS) < IMAGE_SIZE) in_index <= in_index + PAR_COMPS;
         else begin
           in_index <= '0;
           in_image_no <= in_image_no + 1;
         end
       end
       if (done_receive) begin 
         in_index    <= '0;
         in_image_no <= '0;
       end
     end
   end
/*
   // --------------------------------------------------------------------
   // process to compute processing indicies
   // --------------------------------------------------------------------

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       p_row      <= '0; 
       p_col      <= '0;
       p_image_no <= '0;
     end else begin
       if (processing) begin
         p_row      <= '0; 
         p_col      <= '0;
         p_image_no <= '0;
       end
       if (state == ST_PROCESS) begin
         if ((p_col + PAR_COMPS) < IMAGE_WIDTH) p_col <= p_col + PAR_COMPS;
         else                                   p_col <= '0;

         if ((p_col + PAR_COMPS) >= IMAGE_WIDTH) begin
           if ((p_row + 1) < IMAGE_HEIGHT) p_row <= p_row + 1;
           else                            p_row <= '0;
         end

         if (((p_col + PAR_COMPS) >= IMAGE_WIDTH) && ((p_row + 1) >= IMAGE_HEIGHT)) begin
           p_image_no <= p_image_no + 1;
           //$display("incremented p_image_no");
         end
       end
     end
   end  
*/
   // -------------------------------------------------------------------
   // shift register for performing multiplication
   // -------------------------------------------------------------------

   genvar sr, p;

   generate 
     for (sr=0; sr<SHIFT_REGISTER_SIZE - PAR_COMPS; sr++) begin : shift_reg_loop
       always @(posedge clock, negedge reset_n) begin
         if (reset_n == 0)  sh_reg[sr] <= '0;
         else if (processing) sh_reg[sr] <= sh_reg[sr+PAR_COMPS];
       end
     end

     for (p=0; p<PAR_COMPS; p++) begin : shift_reg_load
       always @(posedge clock, negedge reset_n) begin
         if (reset_n == 0) sh_reg[p + SHIFT_REGISTER_SIZE - PAR_COMPS] <= '0;
         else if (shifting) begin
           sh_reg[p + SHIFT_REGISTER_SIZE - PAR_COMPS] <= (head_pixel < IMAGE_SIZE-1) ? images[p_image_no][p_index + p] : '0;
           //$display("shifed in value: %3d p_index = %1d p_image_no = %1d ", (head_pixel < IMAGE_SIZE-1) ? images[p_image_no][p_index + p] : '0, p_index, p_image_no);
           //$display("head_pixel = %1d zero_pixel = %1d tail_pixel = %1d ", head_pixel, zero_pixel, tail_pixel);
           //print_shift_register(sh_reg);
         end
       end
     end 
   endgenerate

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) p_index <= '0;
     else begin
       if (start_process) p_index <= '0;
       if (shifting) p_index <= p_index + PAR_COMPS;
     end
   end

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) p_image_no <= '0;
     else begin
       if (done_receive || done_send) p_image_no <= '0;
       if (done_process)              p_image_no <= p_image_no + 1;
     end
   end

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) out_image_no <= '0;
     else begin
       if (state == ST_DONE) out_image_no <= '0;
       if (done_send)       out_image_no <= out_image_no + 1;
     end
   end

   // --------------------------------------------------------------------
   // logic to perform multiply/accumulate
   // --------------------------------------------------------------------

   assign tail_pixel = head_pixel - (SHIFT_REGISTER_SIZE - 1);
   assign zero_pixel = head_pixel - (FILTER_WIDTH/2 + ((FILTER_HEIGHT/2) * IMAGE_WIDTH));

   genvar r, c;

   generate 
     for (p=0; p<PAR_COMPS; p++) begin
       for (r=0; r<FILTER_HEIGHT; r++) begin
         for (c=0; c<FILTER_WIDTH; c++) begin
           assign product_array[p][r][c] = weight_memory[out_image_no][p_image_no][r][c] * sh_reg[r * IMAGE_WIDTH + p + c] >>> feature_frac_bits;
         end
         always @(posedge clock, negedge reset_n) begin
           if (reset_n == 0) row_sums[p][r] <= '0;
           else              row_sums[p][r] <= product_array[p][r].sum();
         end
       end
       always @(posedge clock, negedge reset_n) begin
         if (reset_n == 0) filter_sums[p] <= '0;
         else              filter_sums[p] <= row_sums[p].sum();
       end
     end
   endgenerate

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) head_pixel <= -1;
     else begin
       if (done_process) head_pixel <= -1;
       if (processing)   head_pixel <= head_pixel + PAR_COMPS;
     end
   end

   // --------------------------------------------------------------------
   // logic to accumulate filter_sums into output image
   // --------------------------------------------------------------------      

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) buff_out_index <= '0;
     else begin
       if (start_process) buff_out_index <= '0;
       if ((processing) && (zero_pixel >= 0)) buff_out_index <= buff_out_index + PAR_COMPS;
     end
   end

   // delayed values for out_index

   always_ff @(posedge clock) buff_out_index_d1 <= buff_out_index;
   always_ff @(posedge clock) buff_out_index_d2 <= buff_out_index_d1;

   always_ff @(posedge clock) processing_d1 <= processing;
   always_ff @(posedge clock) processing_d2 <= processing_d1;

   always_ff @(posedge clock) begin
     if ((processing_d2) && (zero_pixel - 2 >= 0) && (zero_pixel - 2 < IMAGE_SIZE)) begin  // -2 to account for pipeline
       for (int p=0; p<PAR_COMPS; p++) begin
         if (p_image_no == 0) begin
           output_buffer[buff_out_index_d2 + p] <= bias_memory[out_image_no] + filter_sums[p];
           //$display("(1) set output_buffed[%d] = %4x ", buff_out_index_d2 + p, bias_memory[out_image_no] + filter_sums[p]);
           //$display("bias_memory[%1d] = %4x filter_sums[%1d] = %4d ", out_image_no, bias_memory[out_image_no], p, filter_sums[p]);
         end else begin
           output_buffer[buff_out_index_d2 + p] <= output_buffer[buff_out_index_d2 + p] + filter_sums[p];
           //$display("(2) set output_buffed[%d] = %4x ", buff_out_index_d2 + p, output_buffer[buff_out_index_d2 + p] + filter_sums[p]);
           //$display("output_buffer[%1d] = %4x filter_sums[%1d] = %4d ", buff_out_index_d2 + p, output_buffer[buff_out_index_d2 + p], p, filter_sums[p]);
         end
       end
     end
   end
  

/*
   // --------------------------------------------------------------------
   // logic to perform multiply/accumulate
   // --------------------------------------------------------------------

   genvar p, r, c;

   generate 
     for (p=0; p<PAR_COMPS; p++) begin
       for (r=0; r<FILTER_HEIGHT; r++) begin
         for (c=0; c<FILTER_WIDTH; c++) begin
           always_comb begin
             product_array[p][r][c] = '0;
             rr[p][r][c] = p_row - FILTER_HEIGHT/2 + r;
             cc[p][r][c] = p_col - FILTER_HEIGHT/2 + c;
             if (multiply_active & in_bounds(rr,cc)) product_array[p][r][c] = (input_image[in_image][rr[p][r][c]][cc[p][r][c]] * weight_memory[out_image][in_image][r][c]) >>> feature_frac_bits;
           end
         end
         always @(posedge clock, negedge reset_n) begin
           if (reset_n == 0) row_sum[p][r] <= '0;
           else              row_sum[p][r] <= product_array[p][r].sum();
         end  
       end
       always @(posedge clock, negedge reset_n) begin
         if (reset_n == 0) filter_sum[p] <= '0;
         else              filter_sum[p] <= row_sum.sum();
       end
     end
   endgenerate   
*/

   // --------------------------------------------------------------------
   // state machine to read in features
   // --------------------------------------------------------------------

   always_comb begin
     case (rx_state)
       RX_IDLE  : if (receive) next_rx_state = RX_RECV;
       RX_RECV  : if ((in_index == IMAGE_SIZE - PAR_COMPS) &&
                      (in_image_no == input_images - 1)) next_rx_state = RX_DONE;
       RX_DONE  : next_rx_state = RX_IDLE;
       default  : next_rx_state = RX_IDLE;
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
       out_index <= '0;
     end else begin
       if (features_out.valid && features_out.ready) begin
         if ((out_index + 1) < IMAGE_SIZE) out_index <= out_index + 1;
         else out_index <= '0;
       end
       if (done_send) begin
         out_index <= '0;
       end
     end
   end

   // --------------------------------------------------------------------
   // state machine to write out features
   // --------------------------------------------------------------------

   always_comb begin
     case (tx_state)
       TX_IDLE : if (send) next_tx_state = TX_SEND;
       TX_SEND : if ((out_index + 1) == IMAGE_SIZE) next_tx_state = TX_DONE;
       TX_DONE : next_tx_state = TX_IDLE;
       default : next_tx_state = TX_IDLE;
     endcase
   end

   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) tx_state = TX_IDLE;
     else tx_state = next_tx_state;
   end

   assign features_out.valid = tx_state == TX_SEND;
   assign features_out.features[0] = (output_buffer[out_index]>0) ? output_buffer[out_index] : '0;
   // always @(posedge clock) if (features_out.valid && features_out.ready) $display("%4x ", features_out.features[0]);

   // --------------------------------------------------------------------
   // state machine to orchestrate convolution
   // --------------------------------------------------------------------

   always_comb begin
     case (state)
       ST_IDLE    : next_state = ST_RX;
       ST_RX      : next_state = ST_RECV;
       ST_RECV    : if (rx_state == RX_DONE) next_state = ST_RX_DONE;
       ST_RX_DONE : next_state = ST_START;
       ST_START   : next_state = ST_PX;                                     // start of all processing
       ST_PX      : next_state = ST_PROCESS;                                // start of processing one image
       ST_PROCESS : if (p_index == IMAGE_SIZE - PAR_COMPS) next_state = ST_FLUSH;
       ST_FLUSH   : if (zero_pixel == IMAGE_SIZE) next_state = ST_PX_DONE;
       ST_PX_DONE : if ((p_image_no + 1) < input_images) next_state = ST_PX;
                    else next_state = ST_TX;
       ST_TX      : next_state = ST_SEND;                                   // done processing image, send
       ST_SEND    : if (tx_state == TX_DONE) next_state = ST_TX_DONE; 
       ST_TX_DONE : if ((out_image_no + 1) < output_images) next_state = ST_PX;
                    else                                    next_state = ST_DONE;
       ST_DONE    : next_state = ST_IDLE;
       default    : next_state = ST_IDLE;
     endcase
   end
      
   always @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) state = ST_IDLE;
     else state = next_state;
   end

   assign start_receive    = state == ST_RX;
   assign receiving        = state == ST_RECV;
   assign done_receive     = state == ST_RX_DONE;

   assign start_process    = state == ST_PX;
   assign processing       = (state == ST_PROCESS) || (state == ST_FLUSH);
   assign done_process     = state == ST_PX_DONE;
 
   assign start_send       = state == ST_TX;
   assign sending          = state == ST_SEND;
   assign done_send        = state == ST_TX_DONE;

   assign receive  = start_receive;
   assign send     = start_send;
   assign shifting = processing; 

/*
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
*/
//   always @(posedge clock) if (shifting) print_shift_register(sh_reg);

endmodule : convolution
