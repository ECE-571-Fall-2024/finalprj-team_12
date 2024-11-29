
module problem;

  specparam clock_period = 2;
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

  // test stimulus

  int digit_file;
  typedef byte unsigned image_array[28][28];

  byte expected_result;
  image_array image;

  initial begin 
    digit_file = $fopen("testbench_digits.bin", "rb");
    if (digit_file == 0) begin
      $display("Unable to open file \"testbench_digits.bin\" for reading");
      $finish;
    end
  end

  final $fclose(digit_file);

  int foo;

  function automatic void load_image(ref image_array image, output byte label);
    foo = $fread(image, digit_file);
    foo = $fread(label, digit_file);
  endfunction : load_image

  function automatic void print_image(ref image_array image);
    for (int row=0; row<28; row++) begin
      for (int col=0; col<28; col++) begin
        if (image[row][col]>0) $write("%2x", image[row][col]);
        else                   $write("  ");
      end
      $write("\n");
    end
  endfunction : print_image

  initial begin

    @(posedge reset_n);

    repeat (20) begin

      load_image(image, expected_result);
      print_image(image);

      @(posedge clock);
    end
  end
endmodule

