#ifndef REGIONS_H_INCLUDED 
#define REGIONS_H_INCLUDED 


static unsigned int region_map[][2] = { 
  {          0,        500 },  // conv2d weights 
  {        500,         20 },  // conv2d biases 
  {        520,       9000 },  // conv2d_1 weights 
  {       9520,         50 },  // conv2d_1 biases 
  {       9570,      49000 },  // dense weights 
  {      58570,         20 },  // dense biases 
  {      58590,        200 },  // dense_1 weights 
  {      58790,         10 },  // dense_1 biases 
  {      58800,        784 },  // input_image 
  {      59584,       3920 },  // conv2d outputs 
  {      63504,       2450 },  // conv2d_1 outputs 
  {      65954,         20 },  // dense outputs 
  {      65974,         10 },  // dense_1 outputs 
  {      65984, 4294967295 }   // out of bounds 
}; 
 
 
static char region_names[][40] = { 
  { "conv2d weights" }, 
  { "conv2d biases " }, 
  { "conv2d_1 weights" }, 
  { "conv2d_1 biases " }, 
  { "dense weights" }, 
  { "dense biases " }, 
  { "dense_1 weights" }, 
  { "dense_1 biases " }, 
  { "input image " }, 
  { "conv2d outputs " }, 
  { "conv2d_1 outputs " }, 
  { "dense outputs " }, 
  { "dense_1 outputs " }, 
  { "out of bounds " } 
}; 

#endif 
