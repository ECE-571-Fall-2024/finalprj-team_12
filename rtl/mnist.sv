
import mnist_pkg::*;

module mnist(
   input logic           clock,
   input logic           reset_n,
  
   input  feature_type    feature_in,
   input  logic           feature_in_valid,
   output logic           feature_in_ready,

   output feature_type    prediction_out,
   output logic           prediction_out_valid,
   input  logic           prediction_out_ready);

   // instantiate features

   feature_if             pixels_in();
   feature_if             convolved1();
   feature_if             max_pooled1();
   feature_if             convolved2();
   feature_if             max_pooled2();
   feature_if             dense1();
   feature_if             dense2();
   feature_if             predictions_out(); 

   assign pixels_in.features[0] = feature_in;
   assign pixels_in.valid       = feature_in_valid;
   assign feature_in_ready      = pixels_in.ready;

   // instantiate layers  

   convolution #(
        .IMAGE_HEIGHT    (28),
        .IMAGE_WIDTH     (28),
        .FILTER_HEIGHT    (5),
        .FILTER_WIDTH     (5),
        .input_images     (1),
        .output_images   (20),
        .weight_file ("../weights/conv2d_1_weights.hex"),
        .bias_file ("../weights/conv2d_1_biases.hex")
    ) u_convolution_1 (
      .clock (clock),
      .reset_n (reset_n),

      .features_in (pixels_in.in),
      .features_out (convolved1.out));

   max_pool #(
        .IMAGE_HEIGHT (28),
        .IMAGE_WIDTH  (28)
    )u_max_pool_1 (
      .clock (clock),
      .reset_n (reset_n),

      .features_in (convolved1.in),
      .features_out (max_pooled1.out));

   convolution #(
        .IMAGE_HEIGHT    (14),
        .IMAGE_WIDTH     (14),
        .FILTER_HEIGHT    (3),
        .FILTER_WIDTH     (3),
        .input_images    (20),
        .output_images   (50),
        .weight_file ("../weights/conv2d_2_weights.hex"),
        .bias_file ("../weights/conv2d_2_biases.hex")
    )u_convolution_2 (
      .clock (clock),
      .reset_n (reset_n),

      .features_in (max_pooled1.in),
      .features_out (convolved2.out));

   max_pool #(
        .IMAGE_HEIGHT (14),
        .IMAGE_WIDTH  (14)
    )u_max_pool_2 (
      .clock (clock),
      .reset_n (reset_n),

      .features_in (convolved2.in),
      .features_out (max_pooled2.out));

   dense #(
         .INPUT_VECTOR_LENGTH (7*7*50),
         .OUTPUT_VECTOR_LENGTH (20),
         .relu(1),
         .weight_file ("../weights/dense_1_weights.hex"),
         .bias_file ("../weights/dense_1_biases.hex")
    )u_dense_1 ( 
      .clock (clock),
      .reset_n (reset_n),

      .features_in (max_pooled2.in),
      .features_out (dense1.out));

   dense #(
         .INPUT_VECTOR_LENGTH (20),
         .OUTPUT_VECTOR_LENGTH (10),
         .relu(0),
         .weight_file("../weights/dense_2_weights.hex"),
         .bias_file("../weights/dense_2_biases.hex")
    )u_dense_2 ( 
      .clock (clock),
      .reset_n (reset_n),

      .features_in (dense1.in),
      .features_out (dense2.out));

   softmax u_softmax (
      .clock (clock),
      .reset_n (reset_n),

      .features_in (dense2.in),
      .features_out (predictions_out));

   assign prediction_out = predictions_out.features[0];
   assign prediction_out_valid = predictions_out.valid;
   assign predictions_out.ready = prediction_out_ready;

endmodule : mnist
