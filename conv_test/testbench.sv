

import mnist_pkg::*;

module testbench;

  parameter IMAGE_HEIGHT  = 10;
  parameter IMAGE_WIDTH   = 10;
  parameter FILTER_HEIGHT =  3;
  parameter FILTER_WIDTH  =  3;
  parameter INPUT_IMAGES  =  1;
  parameter clock_period  =  2;
  parameter reset_period  = 10;

  // clock and reset

  logic clock;
  logic reset_n;

  initial begin
    clock = 0;
    forever #clock_period clock = ~clock; 
  end 
   
  initial begin
    reset_n = 0;
    repeat (reset_period * 2) #clock_period; 
    reset_n = 1;
  end

  typedef feature_type image_array[IMAGE_HEIGHT][IMAGE_WIDTH];
  typedef weight_type  [FILTER_HEIGHT][FILTER_WIDTH] filter_array;

  // test stimulus

  feature_type   feature_in, feature_out;
  logic          feature_in_valid, feature_in_ready;
  logic          feature_out_valid, feature_out_ready;
 
  image_array    input_image[INPUT_IMAGES], output_image, expected_output;
  filter_array   filter[INPUT_IMAGES];

  // -------------------------------------------------------------------
  // functions for generating stimulus
  // -------------------------------------------------------------------

  // images

  function automatic void random_image(ref image_array image);
    feature_type rv;
    foreach (image[r,c]) begin
      rv = $urandom_range(0, 1<<(feature_frac_bits+2));
      if ($urandom() & 1'b1) rv = -rv;
      image[r][c] = rv;
    end
  endfunction

  function automatic void random_positive(ref image_array image);
    foreach (image[r,c]) image[r][c] = $urandom_range(0, 1<<(feature_frac_bits+2));
  endfunction

  function automatic void random_negative(ref image_array image);
    foreach (image[r,c]) image[r][c] = -$urandom_range(0, 1<<(feature_frac_bits+2));
  endfunction

  function automatic void zero_image(ref image_array image);
    foreach (image[r,c]) image[r][c] = '0;
  endfunction

  function automatic void k_image(feature_type k, ref image_array image);
    foreach (image[r,c]) image[r][c] = k;
  endfunction
 
  function automatic void incrementing_image(ref image_array image);
    foreach (image[r,c]) image[r][c] = r * IMAGE_WIDTH + c;
  endfunction

  // filters

  function automatic void random_filter(ref filter_array filter);
    weight_type rv;
    foreach (filter[r,c]) begin
      rv = $urandom_range(0, 1<<weight_frac_bits);
      if ($urandom() & 1'b1) rv = -rv;
      filter[r][c] = rv;
    end
  endfunction : random_filter

  function automatic void zero_filter(ref filter_array filter);
    foreach (filter[r,c]) filter[r][c] = '0;
  endfunction

  function automatic void identity_filter(ref filter_array filter);
    foreach (filter[r,c]) filter[r][c] = '0;
    filter[FILTER_HEIGHT/2][FILTER_WIDTH/2] = int_to_weight(1); 
  endfunction

  function automatic void negative_identity_filter(ref filter_array filter);
    foreach (filter[r,c]) filter[r][c] = '0;
    filter[FILTER_HEIGHT/2][FILTER_WIDTH/2] = int_to_weight(-1); 
  endfunction

  function automatic void k_filter(feature_type k, ref filter_array filter);
    foreach (filter[r,c]) filter[r][c] = k;
  endfunction
 
  function automatic void incrementing_filter(ref filter_array filter);
    foreach (filter[r,c]) filter[r][c] = r * FILTER_WIDTH + c;
  endfunction

  // -------------------------------------------------------------------
  // reference convolution algorithm
  // -------------------------------------------------------------------

  function automatic logic in_bounds(int r, int c);
    return ((r >= 0) && (r < IMAGE_HEIGHT) && (c >= 0) && (c < IMAGE_WIDTH));
  endfunction

  function automatic void convolution
      (input int            input_images,
       input weight_type    bias_value,
       input image_array    image[], 
       input filter_array   filter[], 
       output image_array   result);

    sum_type sum;

    for (int i=0; i<input_images; i++) begin
      for (int row=0; row<IMAGE_WIDTH; row++) begin
        for (int col=0; col<IMAGE_HEIGHT; col++) begin
          sum = '0;
          for (int fr=0; fr<FILTER_WIDTH; fr++) begin
            for (int fc=0; fc<FILTER_HEIGHT; fc++) begin
              int r = row - ((FILTER_HEIGHT-1)/2) + fr;
              int c = col - ((FILTER_WIDTH-1)/2) + fc;
              feature_type factor_1 = image[i][r][c];
              weight_type  factor_2 = filter[i][fr][fc];
              sum_type product = (factor_1 * factor_2) >>> feature_frac_bits;
              if (in_bounds(r, c)) sum += product;
            end
          end
          result[row][col] = (i==0) ? sum + bias_value : sum + result[row][col];
          if ((i+1) == input_images) if (result[row][col]<0) result[row][col] = '0;  // relu operation
        end
      end
    end
  endfunction : convolution

  // -------------------------------------------------------------------
  // print routines
  // -------------------------------------------------------------------

  task automatic print_image(image_array image);
    for (int r=0; r<IMAGE_HEIGHT; r++) begin
      for (int c=0; c<IMAGE_WIDTH; c++) begin
        $write("%4x ", image[r][c]);
      end
      $write("\n");
    end
  endtask

  task automatic print_image_real(image_array image);
    for (int r=0; r<IMAGE_HEIGHT; r++) begin
      for (int c=0; c<IMAGE_WIDTH; c++) begin
        $write("%6.3f ", feature_to_real(image[r][c]));
      end
      $write("\n");
    end
  endtask

  task automatic print_filter(filter_array filter);
    for (int r=0; r<FILTER_HEIGHT; r++) begin
      for (int c=0; c<FILTER_WIDTH; c++) begin
        $write("%4x ", filter[r][c]);
      end
      $write("\n");
    end
  endtask

  task automatic print_filter_real(filter_array image);
    for (int r=0; r<FILTER_HEIGHT; r++) begin
      for (int c=0; c<FILTER_WIDTH; c++) begin
        $write("%6.3f ", weight_to_real(filter[r][c]));
      end
      $write("\n");
    end
  endtask

  // -------------------------------------------------------------------
  // test stimulus
  // -------------------------------------------------------------------

  feature_if features_in(), features_out();

  typedef enum { I_ZERO, I_RAND, I_RAND_NEG, I_RAND_POS, I_K, I_INCR } image_types;
  typedef enum { F_RAND, F_ZERO, F_IDENT, F_NEG_IDENT, F_K, F_INCR } filter_types;

  initial begin
  
    /*

    // test the stimulus creation routines

    random_image(input_image);
    print_image(input_image);
    print_image_real(input_image);

    zero_image(input_image);
    print_image(input_image);
    print_image_real(input_image);

    k_image(real_to_feature(2.5), input_image);
    print_image(input_image);
    print_image_real(input_image);

    incrementing_image(input_image);
    print_image(input_image);
    print_image_real(input_image);

    random_filter(filter);
    print_filter(filter);
    print_filter_real(filter);

    zero_filter(filter);
    print_filter(filter);
    print_filter_real(filter);

    k_filter(real_to_weight(1.23), filter);
    print_filter(filter);
    print_filter_real(filter);
   
    incrementing_filter(filter);
    print_filter(filter);
    print_filter_real(filter);

    identity_filter(filter);
    print_filter(filter);
    print_filter_real(filter);

    */

    random_negative(input_image[0]);
    negative_identity_filter(filter[0]);
    //identity_filter(filter[1]);

    for (int i=0; i<INPUT_IMAGES; i++) begin
      for (int r=0; r<FILTER_HEIGHT; r++) begin
        u_convolution_1.weight_memory[0][i][r] = filter[i][r];
      end
    end 

    u_convolution_1.bias_memory[0] = '0;
    
    @(posedge reset_n);
    @(posedge clock);
    features_in.valid = 0;
    features_out.ready = 0;

    repeat (100) @(posedge clock);

    features_in.valid = 1;
    foreach(input_image[i,r,c]) begin
      features_in.features[0] = input_image[i][r][c];
      @(posedge clock);
      while (~features_in.ready) @(posedge clock);
    end
    features_in.valid = 0;

    @(posedge clock); 
   
    features_out.ready = 1;
    foreach(output_image[r,c]) begin
      while (~features_out.valid) @(posedge clock);
      output_image[r][c] = features_out.features[0];
      @(posedge clock);
    end

    print_image(input_image[0]);
    print_image_real(input_image[0]);
    print_filter(filter[0]);
    print_image(output_image);
    print_image_real(output_image);

    convolution(1, 0, input_image, filter, expected_output);

    print_image(expected_output);
    print_image_real(expected_output);

    if (expected_output == output_image) $display("Success! ");
    else                                 $display("Fail!    ");
    $finish;
  end

  // -------------------------------------------------------------------
  // instantiate and conncect DUT
  // -------------------------------------------------------------------

   convolution #(
        .IMAGE_HEIGHT    (IMAGE_HEIGHT),
        .IMAGE_WIDTH     (IMAGE_WIDTH),
        .FILTER_HEIGHT   (FILTER_HEIGHT),
        .FILTER_WIDTH    (FILTER_WIDTH),
        .input_images    (1),
        .output_images   (1),
        .load_weights    (0)
    ) u_convolution_1 (
      .clock (clock),
      .reset_n (reset_n),

      .features_in  (features_in),
      .features_out (features_out));
  
endmodule
