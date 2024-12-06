

import mnist_pkg::*;

module testbench;

  parameter IMAGE_HEIGHT    =  10;
  parameter IMAGE_WIDTH     =  10;
  parameter FILTER_HEIGHT   =   3;
  parameter FILTER_WIDTH    =   3;
  parameter INPUT_IMAGES    =   1;
  parameter OUTPUT_IMAGES   =   1;
  parameter TEST_ITERATIONS = 100;
  parameter clock_period    =   2;
  parameter reset_period    =  10;

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

  typedef feature_type image_array [IMAGE_HEIGHT][IMAGE_WIDTH];
  typedef weight_type  [FILTER_HEIGHT][FILTER_WIDTH] filter_array;

  // test stimulus

  feature_type   feature_in, feature_out;
  logic          feature_in_valid, feature_in_ready;
  logic          feature_out_valid, feature_out_ready;
 
  image_array    input_image[INPUT_IMAGES], output_images[OUTPUT_IMAGES], expected_output[OUTPUT_IMAGES];
  filter_array   filter[OUTPUT_IMAGES][INPUT_IMAGES];
  weight_type    biases[OUTPUT_IMAGES];

  // -------------------------------------------------------------------
  // functions for generating stimulus
  // -------------------------------------------------------------------

  // images

  class random_positive_image_class;
    rand image_array rand_img;
    constraint positive_only { foreach (rand_img[r,c]) (rand_img[r][c] > 0); }
  endclass

  class random_negative_image_class;
    rand image_array rand_img;
    constraint negative_only { foreach (rand_img[r,c]) (rand_img[r][c] < 0); }
  endclass

  random_positive_image_class rpi = new();
  random_negative_image_class rni = new();

  function automatic void random_image(ref image_array image);
    bit ret = std::randomize(image);
  endfunction : random_image

  function automatic void random_positive_image(ref image_array image);
    bit ret = rpi.randomize();
    if (ret) image = rpi.rand_img;
    else $display("randomize failed! ");
  endfunction

  function automatic void random_negative_image(ref image_array image);
    bit ret = rni.randomize();
    if (ret) image = rni.rand_img;
    else $display("randomize failed! ");
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
    std::randomize(filter);
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
      (input int            num_input_images,
       input int            num_output_images,
       input weight_type    bias_values[OUTPUT_IMAGES],
       input image_array    image[INPUT_IMAGES], 
       input filter_array   filter[OUTPUT_IMAGES][INPUT_IMAGES], 
       output image_array   result[OUTPUT_IMAGES]);

    sum_type sum;

    for (int o=0; o<num_output_images; o++) begin
      for (int i=0; i<num_input_images; i++) begin
        for (int row=0; row<IMAGE_WIDTH; row++) begin
          for (int col=0; col<IMAGE_HEIGHT; col++) begin
            sum = '0;
            for (int fr=0; fr<FILTER_WIDTH; fr++) begin
              for (int fc=0; fc<FILTER_HEIGHT; fc++) begin
                int r = row - ((FILTER_HEIGHT-1)/2) + fr;
                int c = col - ((FILTER_WIDTH-1)/2) + fc;
                feature_type factor_1 = image[i][r][c];
                weight_type  factor_2 = filter[o][i][fr][fc];
                sum_type product = (factor_1 * factor_2) >>> feature_frac_bits;
                if (in_bounds(r, c)) sum += product;
              end
            end
            result[o][row][col] = (i==0) ? sum + bias_values[o] : sum + result[o][row][col];
            if ((i+1) == num_input_images) if (result[o][row][col]<0) result[o][row][col] = '0;  // relu operation
          end
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
  endtask : print_image

  task automatic print_image_real(image_array image);
    for (int r=0; r<IMAGE_HEIGHT; r++) begin
      for (int c=0; c<IMAGE_WIDTH; c++) begin
        $write("%6.3f ", feature_to_real(image[r][c]));
      end
      $write("\n");
    end
  endtask : print_image_real

  task automatic print_filter(filter_array filter);
    for (int r=0; r<FILTER_HEIGHT; r++) begin
      for (int c=0; c<FILTER_WIDTH; c++) begin
        $write("%4x ", filter[r][c]);
      end
      $write("\n");
    end
  endtask : print_filter

  task automatic print_filter_real(filter_array image);
    for (int r=0; r<FILTER_HEIGHT; r++) begin
      for (int c=0; c<FILTER_WIDTH; c++) begin
        $write("%6.3f ", weight_to_real(filter[r][c]));
      end
      $write("\n");
    end
  endtask : print_filter_real

  // -------------------------------------------------------------------
  // test stimulus
  // -------------------------------------------------------------------

  feature_if features_in(), features_out();

  typedef enum { I_ZERO, I_RAND, I_RAND_NEG, I_RAND_POS, I_K, I_INCR } image_type;
  typedef enum { F_RAND, F_ZERO, F_IDENT, F_NEG_IDENT, F_K, F_INCR } filter_type;

  image_type image_stim[] = { I_INCR, I_ZERO, I_RAND, I_RAND_NEG, I_RAND_POS, I_K, I_INCR };
  filter_type filter_stim[] = { F_IDENT, F_RAND, F_ZERO, F_IDENT, F_NEG_IDENT, F_K, F_INCR };

  function automatic void get_image(input image_type it, ref image_array i);
    case (it)
     I_ZERO      : zero_image(i);
     I_RAND      : random_image(i);
     I_RAND_NEG  : random_negative_image(i);
     I_RAND_POS  : random_positive_image(i);
     I_K         : k_image($urandom(feature_frac_bits + 2), i);
     I_INCR      : incrementing_image(i);
    endcase
  endfunction : get_image

  function automatic void get_filter(input filter_type ft, ref filter_array f);
    case (ft) 
     F_ZERO      : zero_filter(f);
     F_RAND      : random_filter(f);
     F_IDENT     : identity_filter(f);
     F_NEG_IDENT : negative_identity_filter(f);
     F_K         : k_filter($urandom(weight_frac_bits), f);
     F_INCR      : incrementing_filter(f);
    endcase
  endfunction : get_filter

  function automatic string image_name(input image_type it);
    case (it)
     I_ZERO      : return("zero_image");
     I_RAND      : return("ramdom_image");
     I_RAND_NEG  : return("random_negative_image");
     I_RAND_POS  : return("random_positive_image");
     I_K         : return("constant image");
     I_INCR      : return("incrementing_image");
    endcase
  endfunction : image_name

  function automatic string filter_name(input filter_type ft);
    case (ft)
     F_ZERO      : return("zero_filter");
     F_RAND      : return("random_filter");
     F_IDENT     : return("identity_filter");
     F_NEG_IDENT : return("negative_identity_filter");
     F_K         : return("constant_filter");
     F_INCR      : return("incrementing_filter");
    endcase
  endfunction : filter_name

  task automatic run_convolution(
    input image_array input_image[INPUT_IMAGES],
    input filter_array filter[OUTPUT_IMAGES][INPUT_IMAGES],
    input weight_type biases[OUTPUT_IMAGES],
    ref   image_array output_images[OUTPUT_IMAGES]);

    // set weight_memory

    for (int o=0; o<OUTPUT_IMAGES; o++) begin
      for (int i=0; i<INPUT_IMAGES; i++) begin
        for (int r=0; r<FILTER_HEIGHT; r++) begin
          u_convolution_1.weight_memory[o][i][r] = filter[o][i][r];
        end
      end
    end 

    for (int l=0; l<OUTPUT_IMAGES; l++) begin
      u_convolution_1.bias_memory[l] = biases[l];
    end

    // drive features to DUT
 
    features_in.valid = 1;
    foreach(input_image[i,r,c]) begin
      features_in.features[0] = input_image[i][r][c];
      @(posedge clock);
      while (~features_in.ready) @(posedge clock);
    end
    features_in.valid = 0;

    @(posedge clock); 
  
    features_out.ready = 1;
    foreach(output_images[o,r,c]) begin
      while (~features_out.valid) @(posedge clock);
      output_images[o][r][c] = features_out.features[0];
      @(posedge clock);
    end

  endtask : run_convolution

  function automatic logic compare(image_array a[OUTPUT_IMAGES], image_array b[OUTPUT_IMAGES]);
   
    logic ret = 1;

    foreach(a[i,r,c]) begin
      if (a[i][r][c] != b[i][r][c]) begin
        $display("Miscompare at image=%1d row=%1d col=%1d expected=%4x found=%4x ", i, r, c, a[i][r][c], b[i][r][c]);
        ret = 0;
      end
    end
    return ret;
  endfunction : compare

  task automatic print_failure(
      input image_array images[],
      input filter_array filters[][],
      input image_array  output_image[],
      input image_array  expected_output[]);

    $display(" ");
    $display("Error: test failed: ");
    $display(" ");
    for (int o=0; o<OUTPUT_IMAGES; o++) begin
      $display("output image: %1d ", o);
      for (int i=0; i<INPUT_IMAGES; i++) begin
        $display("\ninput image: %1d", i);
        print_image(input_image[i]);
        $display("\nfilter: %1d ", i);
        print_filter(filter[o][i]);
      end
      $display("\noutput image: ");
      print_image(output_image[o]);
      $display("\nexpected output: ");
      print_image(expected_output[o]);
    end
    $display("\n\n");
    $finish;

  endtask : print_failure

  task automatic exercise_stimulus_creation( );

    // test the stimulus creation routines

    random_image(input_image[0]);
    print_image(input_image[0]);
    print_image_real(input_image[0]);

    zero_image(input_image[0]);
    print_image(input_image[0]);
    print_image_real(input_image[0]);

    k_image(real_to_feature(2.5), input_image[0]);
    print_image(input_image[0]);
    print_image_real(input_image[0]);

    incrementing_image(input_image[0]);
    print_image(input_image[0]);
    print_image_real(input_image[0]);

    random_filter(filter[0][0]);
    print_filter(filter[0][0]);
    print_filter_real(filter[0][0]);

    zero_filter(filter[0][0]);
    print_filter(filter[0][0]);
    print_filter_real(filter[0][0]);

    k_filter(real_to_weight(1.234), filter[0][0]);
    print_filter(filter[0][0]);
    print_filter_real(filter[0][0]);
   
    incrementing_filter(filter[0][0]);
    print_filter(filter[0][0]);
    print_filter_real(filter[0][0]);

    identity_filter(filter[0][0]);
    print_filter(filter[0][0]);
    print_filter_real(filter[0][0]);

  endtask : exercise_stimulus_creation
    

  // -------------------------------------------------------
  // main test stimulus
  // -------------------------------------------------------

  initial begin
  
    $display("Running convolution test ");
    $display("image_height: %1d ",  IMAGE_HEIGHT);
    $display("image_width: %1d ",   IMAGE_WIDTH);
    $display("filter_height: %1d ", FILTER_HEIGHT);
    $display("filter_width: %1d ",  FILTER_WIDTH);
    $display("input_images: %1d ",  INPUT_IMAGES);
    $display("output_images: %1d ", OUTPUT_IMAGES);

    // wait for reset, align on posedge clock

    @(posedge reset_n);
    @(posedge clock);
  
    // deassert control lines

    features_in.valid = 0;
    features_out.ready = 0;

    repeat (100) @(posedge clock);

    // combinations of stimuli

    foreach (image_stim[i]) begin
      foreach (filter_stim[f]) begin
        for (int img=0; img<INPUT_IMAGES; img++) begin
          get_image(image_stim[i], input_image[img]);
          for (int o=0; o<OUTPUT_IMAGES; o++) begin
            get_filter(filter_stim[f], filter[o][img]);
          end
        end

        foreach (biases[b]) biases[b] = $urandom_range(0,1023) - 512; 

        convolution(INPUT_IMAGES, OUTPUT_IMAGES, biases, input_image, filter, expected_output);

        run_convolution(input_image, filter, biases, output_images);

        $display("running test: %s with %s ", image_name(image_stim[i]), filter_name(filter_stim[f]));

        if (!compare(expected_output, output_images)) print_failure(input_image, filter, output_images, expected_output);

      end
    end

    // random tests

    $display("Running %1d random test iterations ", TEST_ITERATIONS);
    
    repeat (TEST_ITERATIONS) begin
      for (int img=0; img<INPUT_IMAGES; img++) begin
        random_image(input_image[img]);
        for (int omg=0; omg<OUTPUT_IMAGES; omg++) begin
          random_filter(filter[omg][img]);
        end
      end

      convolution(INPUT_IMAGES, OUTPUT_IMAGES, biases, input_image, filter, expected_output);

      run_convolution(input_image, filter, biases, output_images);

      if (expected_output != output_images) print_failure(input_image, filter, output_images, expected_output);
    end

    // if we get here, everything worked
    $display("Convolution tests passed! ");
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
        .input_images    (INPUT_IMAGES),
        .output_images   (OUTPUT_IMAGES),
        .load_weights    (0)
    ) u_convolution_1 (
      .clock (clock),
      .reset_n (reset_n),

      .features_in  (features_in),
      .features_out (features_out));
  
endmodule
