import mnist_pkg::*;

interface feature_if #(
    parameter NUM_FEATURES = 1
  );

  feature_type [NUM_FEATURES] features;
  logic                       valid;
  logic                       ready;
   
  modport in  ( input  features, input  valid, output ready);
  modport out ( output features, output valid, input  ready);

endinterface : feature_if
