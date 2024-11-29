#include <stdio.h>
#include <malloc.h>

static unsigned int region_map[][3] = {
  {          0,        500,   25 },  // conv2d weights
  {        500,         20,    1 },  // conv2d biases
  {        520,       9000,    9 },  // conv2d_1 weights
  {       9520,         50,    1 },  // conv2d_1 biases
  {       9570,      49000,    1 },  // dense weights
  {      58570,         20,    1 },  // dense biases
  {      58590,        200,    1 },  // dense_1 weights
  {      58790,         10,    1 },  // dense_1 biases
  {      58800,        784,    0 },  // input_image
  {      59584,       3920,    0 },  // conv2d outputs
  {      63504,       2450,    0 },  // conv2d_1 outputs
  {      65954,         20,    0 },  // dense outputs
  {      65974,         10,    0 },  // dense_1 outputs
  {      65984, 4294967295,    0 }   // out of bounds
};

static char region_names[][40] = {
  { "conv2d_1_weights.hex" },
  { "conv2d_1_biases.hex" },
  { "conv2d_2_weights.hex" },
  { "conv2d_2_biases.hex" },
  { "dense_1_weights.hex" },
  { "dense_1_biases.hex" },
  { "dense_2_weights.hex" },
  { "dense_2_biases.hex" },
  { "input image " },
  { "conv2d outputs " },
  { "conv2d_1 outputs " },
  { "dense outputs " },
  { "dense_1 outputs " },
  { "out of bounds " }
};


main ()
{
  float *weights = (float *) malloc (58800 * sizeof(float));
  FILE *f = fopen("weights_float.bin", "rb");
  int i, j, k;  
  long b;
  float x;

  fread(weights, sizeof(float), 58800, f);
  fclose(f);

  for (i=0; i<25; i++) printf("w[%d] = %f \n", i, weights[i]);
  for (i=0; i<8; i++) {
    
    f = fopen(region_names[i], "w");
    
    for (j=0; j<region_map[i][1]; j+=region_map[i][2]) {
      for (k=0; k<region_map[i][2]; k++) {
        // b = weights[region_map[i][0]+j+region_map[i][2]-k-1] * 0x100;
        b = weights[region_map[i][0]+j+k] * 0x100;
        fprintf(f, "%04x", ((unsigned long) b) & 0xFFFF); // , weights[region_map[i][0]+j]);
      }
      fprintf(f, "\n");
    }
    fclose(f);
  }
}

