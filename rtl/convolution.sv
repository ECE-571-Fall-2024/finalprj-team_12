
import mnist_pkg::*;

module convolution #(
   parameter IMAGE_HEIGHT  = 28,
   parameter IMAGE_WIDTH   = 28,
   parameter FILTER_HEIGHT =  5,
   parameter FILTER_WIDTH  =  5,
   parameter input_images  =  1,
   parameter output_images = 20,
   parameter load_weights  =  1,
   parameter PAR_COMPS     =  1,
   parameter weight_file   = "weights.hex",
   parameter bias_file     = "biases.hex",
   parameter INDUCE_FAILURE = 0
 )(
   input logic         clock,
   input logic         reset_n,

   feature_if          features_in,
   feature_if          features_out);

//----------------------------------------------------------------//

   parameter IMAGE_SIZE          = IMAGE_HEIGHT * IMAGE_WIDTH;
   parameter F_IMAGE_WIDTH       = IMAGE_WIDTH + (FILTER_WIDTH/2);
   parameter F_IMAGE_SIZE        = IMAGE_HEIGHT * F_IMAGE_WIDTH;
   parameter SHIFT_REGISTER_SIZE = ((FILTER_HEIGHT - 1) * F_IMAGE_WIDTH) + FILTER_WIDTH + (PAR_COMPS - 1);

   typedef weight_type [FILTER_WIDTH][FILTER_HEIGHT] filter_type;

   weight_type   bias_memory[output_images];
   filter_type   weight_memory [output_images][input_images];
   feature_type  output_buffer        [IMAGE_HEIGHT * F_IMAGE_WIDTH], 
                 images [input_images][IMAGE_HEIGHT * F_IMAGE_WIDTH];
   feature_type  sh_reg[SHIFT_REGISTER_SIZE];

   logic [$clog2(input_images):0]  in_image_no;
   logic [$clog2(input_images):0]  p_image_no;
   logic [$clog2(output_images):0] out_image_no;

   sum_type                        product_array [PAR_COMPS][FILTER_HEIGHT][FILTER_WIDTH];
   sum_type                        row_sums[PAR_COMPS][FILTER_HEIGHT];
   sum_type                        filter_sums[PAR_COMPS];

   initial begin
    $display("image height: %1d ", IMAGE_HEIGHT);
    $display("image width:  %1d ", IMAGE_WIDTH);
    $display("fimage width: %1d ", F_IMAGE_WIDTH);
    $display("image size:   %1d ", IMAGE_SIZE);
    $display("shift reg size: %1d ", SHIFT_REGISTER_SIZE);
   end

   // load weight and bias memories

   initial begin
     if (load_weights) begin
       $readmemh(weight_file, weight_memory);
       $readmemh(bias_file, bias_memory);
     end
   end

   // helper funcitons

   // coverage off

   function automatic void print_image(ref feature_type image[IMAGE_HEIGHT][F_IMAGE_WIDTH]);
     for (int r=0; r<IMAGE_HEIGHT; r++) begin
       for (int c=0; c<F_IMAGE_WIDTH; c++) begin
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
       for (int c=0; c<F_IMAGE_WIDTH; c++) begin
         $write("%3d ", sr[r*F_IMAGE_WIDTH+c]);
       end
       $write("\n");
     end
     for (int c=0; c<FILTER_WIDTH + (PAR_COMPS - 1); c++) begin
       $write("%3d ", sr[(FILTER_HEIGHT-1)*F_IMAGE_WIDTH+c]);
     end
     $write("\n\n");
   endfunction
  
   // coverage on

   // signals, enums for input and output state machines

   logic start_receive, receiving,  done_receive;
   logic start_process, processing, done_process; 
   logic start_send,    sending,    done_send;
   logic send, receive;
   logic shifting;

   logic [$clog2(IMAGE_SIZE):0] in_index, out_index;
   logic signed [$clog2(IMAGE_SIZE + 2 * SHIFT_REGISTER_SIZE):0] p_index;
   typedef struct {
     logic signed [$clog2(IMAGE_SIZE + 2 * SHIFT_REGISTER_SIZE):0] head_pixel, zero_pixel, tail_pixel;
   } shift_register_indices_type;

   shift_register_indices_type sr_idx;

   typedef enum logic [3:0] {ST_IDLE, ST_RX, ST_RECV, ST_RX_DONE, ST_START, ST_PX, ST_PROCESS, ST_FLUSH, ST_PX_DONE, ST_TX, ST_SEND, ST_TX_DONE, ST_DONE} st_state_type;
   typedef enum logic [1:0] {RX_IDLE, RX_RECV, RX_DONE} rx_state_type;
   typedef enum logic [1:0] {TX_IDLE, TX_SEND, TX_DONE} tx_state_type;

   st_state_type state, next_state;
   rx_state_type rx_state, next_rx_state;
   tx_state_type tx_state, next_tx_state;

   // --------------------------------------------------------------------
   // process to load features into image array
   // --------------------------------------------------------------------

   logic [$clog2(IMAGE_WIDTH)]  in_col;
   logic [$clog2(IMAGE_HEIGHT)] in_row;

   assign in_index = in_row * F_IMAGE_WIDTH + in_col;

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin 
       in_row <= '0;
       in_col <= '0;
       in_image_no <= '0;
       // foreach(images[i,r,c]) images[i][r][c] <= '0;
       images <= '{default:0};
     end else begin
       if (features_in.ready && features_in.valid) begin
         images[in_image_no][in_index] = features_in.features[0];
         if ((in_col + 1) < IMAGE_WIDTH) in_col <= in_col + 1;
         else begin
           in_col <= 0;
           if ((in_row + 1) < IMAGE_HEIGHT) in_row <= in_row + 1;
           else begin
             in_row <= 0;
             in_image_no <= in_image_no +1;
           end
         end
       end
     end
     if (done_receive) begin 
       in_row <= '0;
       in_col <= '0;
       in_image_no <= '0;
     end
   end

   // -------------------------------------------------------------------
   // shift register for performing multiplication
   // -------------------------------------------------------------------

   genvar sr, p;

   generate 
     for (sr=0; sr<SHIFT_REGISTER_SIZE - PAR_COMPS; sr++) begin : shift_reg_loop
       always_ff @(posedge clock, negedge reset_n) begin
         if (reset_n == 0)  sh_reg[sr] <= '0;
         else if (processing) sh_reg[sr] <= sh_reg[sr+PAR_COMPS];
       end
     end

     for (p=0; p<PAR_COMPS; p++) begin : shift_reg_load
       always_ff @(posedge clock, negedge reset_n) begin
         if (reset_n == 0) sh_reg[p + SHIFT_REGISTER_SIZE - PAR_COMPS] <= '0;
         else if (shifting) begin
           sh_reg[p + SHIFT_REGISTER_SIZE - PAR_COMPS] <= (sr_idx.head_pixel + p < F_IMAGE_SIZE-1) ? images[p_image_no][p_index + p] : '0;
           // $display("shifed in value: %3d p_index = %1d p_image_no = %1d p=%1d", (sr_idx.head_pixel < IMAGE_SIZE-1) ? images[p_image_no][p_index + p] : '0, p_index, p_image_no, p);
           // $display("head_pixel = %1d zero_pixel = %1d tail_pixel = %1d ", sr_idx.head_pixel, sr_idx.zero_pixel, sr_idx.tail_pixel);
           // print_shift_register(sh_reg);
         end
       end
     end 
   endgenerate

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) p_index <= '0;
     else begin
       if (start_process) p_index <= '0;
       if (shifting) p_index <= p_index + PAR_COMPS;
     end
   end

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) p_image_no <= '0;
     else begin
       if (done_receive || done_send) p_image_no <= '0;
       if (done_process)              p_image_no <= p_image_no + 1;
     end
   end

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) out_image_no <= '0;
     else begin
       if (state == ST_DONE) out_image_no <= '0;
       if (done_send)       out_image_no <= out_image_no + 1;
     end
   end

   // --------------------------------------------------------------------
   // logic to perform multiply/accumulate
   // --------------------------------------------------------------------

   assign sr_idx.tail_pixel = sr_idx.head_pixel - (SHIFT_REGISTER_SIZE - 1);
   assign sr_idx.zero_pixel = sr_idx.head_pixel - (FILTER_WIDTH/2 + ((FILTER_HEIGHT/2) * F_IMAGE_WIDTH) + (PAR_COMPS - 1));

   genvar r, c;

   generate 
     for (p=0; p<PAR_COMPS; p++) begin
       for (r=0; r<FILTER_HEIGHT; r++) begin
         for (c=0; c<FILTER_WIDTH; c++) begin
           assign product_array[p][r][c] = weight_memory[out_image_no][p_image_no][r][c] * sh_reg[r * F_IMAGE_WIDTH + c + p] >>> weight_frac_bits;
         end
         always_ff @(posedge clock, negedge reset_n) begin
           if (reset_n == 0) row_sums[p][r] <= '0;
           else              row_sums[p][r] <= product_array[p][r].sum();
         end
       end
       always_ff @(posedge clock, negedge reset_n) begin
         if (reset_n == 0) filter_sums[p] <= '0;
         else              filter_sums[p] <= row_sums[p].sum();
       end
     end
   endgenerate

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) sr_idx.head_pixel <= -1;
     else begin
       if (done_process) sr_idx.head_pixel <= -1;
       if (processing)   sr_idx.head_pixel <= sr_idx.head_pixel + PAR_COMPS;
     end
   end

   // --------------------------------------------------------------------
   // logic to accumulate filter_sums into output image
   // --------------------------------------------------------------------      

   logic signed [$clog2(IMAGE_SIZE):0] offset [PAR_COMPS];

   always_ff @(posedge clock) begin
     for (int p=0; p<PAR_COMPS; p++) begin
       offset[p] <= sr_idx.zero_pixel - PAR_COMPS + p; 
       if ((0 <= offset[p]) && (offset[p] < F_IMAGE_SIZE)) begin
         if (p_image_no == 0) output_buffer[offset[p]] <= filter_sums[p] + bias_memory[out_image_no];
         else                 output_buffer[offset[p]] <= filter_sums[p] + output_buffer[offset[p]];

         // to show efficacy of testcase induce failure will randomly corrupt output
         if (INDUCE_FAILURE) if ($urandom_range(0, 99) == 5) begin
           output_buffer[offset[p]] <= $urandom_range(0,1023);
           // $display("Failure induced!");
         end

       end
     end
   end

   // --------------------------------------------------------------------
   // state machine to read in features
   // --------------------------------------------------------------------

   always_comb begin
     case (rx_state)
       RX_IDLE  : if (receive) next_rx_state = RX_RECV;
       RX_RECV  : if ((in_col == IMAGE_WIDTH - 1) &&
                      (in_row == IMAGE_HEIGHT - 1) && 
                      (in_image_no == input_images - 1)) next_rx_state = RX_DONE;
       RX_DONE  : next_rx_state = RX_IDLE;
       default  : next_rx_state = RX_IDLE;
     endcase
   end

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) rx_state = RX_IDLE;
     else rx_state = next_rx_state;
   end

   assign features_in.ready = rx_state == RX_RECV;
  
   // --------------------------------------------------------------------
   // process to write out processed image
   // --------------------------------------------------------------------

   logic [$clog2(IMAGE_HEIGHT)] out_row;
   logic [$clog2(IMAGE_WIDTH)] out_col;

   assign out_index = out_row * F_IMAGE_WIDTH + out_col;

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) begin
       out_row <= '0;
       out_col <= '0;
     end else begin
       if (features_out.valid && features_out.ready) begin
         if ((out_col + 1) < IMAGE_WIDTH) out_col <= out_col + 1;
         else begin
           out_col <= 0;
           if ((out_row + 1) < IMAGE_HEIGHT) out_row <= out_row + 1;
           else                              out_row <= '0;
         end
       end
       if (done_send) begin
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
       TX_SEND : if (((out_row + 1) >= IMAGE_HEIGHT) &&
                     ((out_col + 1) >= IMAGE_WIDTH)) next_tx_state = TX_DONE;
       TX_DONE : next_tx_state = TX_IDLE;
       default : next_tx_state = TX_IDLE;
     endcase
   end

   always_ff @(posedge clock, negedge reset_n) begin
     if (reset_n == 0) tx_state = TX_IDLE;
     else tx_state = next_tx_state;
   end

   assign features_out.valid = tx_state == TX_SEND;
   assign features_out.features[0] = (output_buffer[out_index]>0) ? output_buffer[out_index] : '0;

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
       ST_PROCESS : if (p_index >= F_IMAGE_SIZE - PAR_COMPS) next_state = ST_FLUSH;
       ST_FLUSH   : if (sr_idx.zero_pixel >= F_IMAGE_SIZE) next_state = ST_PX_DONE;
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
      
   always_ff @(posedge clock, negedge reset_n) begin
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

endmodule : convolution
