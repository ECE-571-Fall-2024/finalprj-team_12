
import mnist_pkg::*;

module testbench;

  parameter clock_period =  2;
  parameter reset_period = 10;

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

  typedef byte unsigned image_array[28][28];

  // test stimulus

  feature_type   feature_in, prediction_out;
  logic          feature_in_valid, feature_in_ready;
  logic          prediction_out_valid, prediction_out_ready;
  int            digit_file, r;
  image_array    image;
  int            mispred;
  const int      num_tests = 20;
  real           accuracy;
  feature_type   predictions[10];
  real           real_prediction;
  byte           predicted_value, image_label;

  // -------------------------------------------------------------------
  // file handling for input images
  // -------------------------------------------------------------------

  initial begin 
    digit_file = $fopen("../data/testbench_digits.bin", "rb");
    if (digit_file == 0) begin
      $display("Unable to open file \"testbench_digits.bin\" for reading");
      $finish;
    end
  end

  final $fclose(digit_file);

  // -------------------------------------------------------------------
  // task for loading image and expected result from image file
  // -------------------------------------------------------------------

  task automatic load_image(ref image_array image, output byte label);
    r = $fread(image, digit_file);
    if (r != 28*28) begin
      $display("unable to read stimulus file, expected %d, read %d ", 28*28, r);
      $finish;
    end
    r = $fread(label, digit_file);
    if (r != 1) begin
      $display("unable to read stimulus file, expected %d, read %d ", 1, r);
      $finish;
    end
  endtask : load_image

  // -------------------------------------------------------------------
  // function for printing image 
  // -------------------------------------------------------------------

  function automatic void print_image(ref image_array image);
    for (int row=0; row<28; row++) begin
      for (int col=0; col<28; col++) begin
        if (image[row][col]>0) $write("%2x", image[row][col]);
        else                   $write("  ");
      end
      $write("\n");
    end
  endfunction : print_image

  // -------------------------------------------------------------------
  // function for determining largest predicted value 
  // -------------------------------------------------------------------

  function automatic byte max_p(input feature_type p[10]);
    byte biggest = 0;
    foreach (p[i]) if (p[biggest]<p[i]) biggest = i;
    return biggest;
  endfunction : max_p

  // -------------------------------------------------------------------
  // main DUT stimulus code
  // -------------------------------------------------------------------

  initial begin

    // deassert control signals, initialize error count

    feature_in_valid = 0;
    prediction_out_ready = 0;
    mispred = 0;

    // wait for reset to complete

    @(posedge reset_n);
    @(posedge clock);

    repeat (num_tests) begin // there are 20 images in the stimulus file

      repeat(100) @(posedge clock);
    
      load_image(image, image_label);  // get image to process
      print_image(image);

      // drive image into prediction pipeline

      feature_in = image[0][0];
      @(posedge clock);
      feature_in_valid = 1;
      
      for (int row=0; row<28; row++) begin
        for (int col=0; col<28; col++) begin
          feature_in = image[row][col];
          @(posedge clock);
          while (!feature_in_ready) @(posedge clock);
        end
      end
    
      feature_in_valid = 0;

      // read predictions out

      prediction_out_ready = 1;
   
      for (int d=0; d<10; d++) begin
        while (!prediction_out_valid) @(posedge clock);
        predictions[d] = prediction_out;
        @(posedge clock);
        real_prediction = real'(predictions[d]) / real'(32'h100);
        $display("prediction[%1d] = %f (%04x) ", d, real_prediction, predictions[d]);
      end

      prediction_out_ready = 0;

      // check results

      predicted_value = max_p(predictions);


      if (predicted_value == image_label) begin
        $display("\nPredicted: %d Image label: %d -- Correct prediction ", predicted_value, image_label);
      end else begin 
        $display("\nPredicted: %d Image label: %d -- Missed prediction ", predicted_value, image_label);
        mispred++;
      end
    end

    // report results and exit

    if (mispred == 1) $display("\nTest complete: %1d misprediction  ", mispred);
    else              $display("\nTest complete: %1d mispredictions ", mispred);

    accuracy = real'(num_tests - mispred)/real'(num_tests);
    $display("Accuracy: %6.4f percent ", accuracy * 100.0);

    if (accuracy >= 0.85) $display("Test passed! \n\n");
    else                  $display("Test failed! \n\n");
   
    $finish;
  end


  // instantiate dut

  mnist dut(.*);
/*
     .clock                (clock),
     .reset_n              (reset_n),
   
     .feature_in           (feature_in),
     .feature_in_valid     (feature_in_valid),
     .feature_in_ready     (feature_in_ready),

     .prediction_out       (prediction_out),
     .prediction_out_ready (prediction_out_ready),
     .prediction_out_valid (prediction_out_valid));
*/
endmodule : testbench
