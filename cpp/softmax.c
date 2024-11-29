
#include <stdio.h>
#include "svdpi.h"
#include "math.h"

void softmax(int raw_predictions[10], int predictions[10])
{
   float raw_real[10];
   float raw_exp[10];
   float real_predictions[10];
   float exp_sum;
   int i;
   float f[10];

   for (i=0; i<10; i++) {
     raw_real[i] = ((float) raw_predictions[i])/256.0;
     raw_exp[i] = exp(raw_real[i]);
     exp_sum += raw_exp[i];
   }

   for (i=0; i<10; i++) {
     real_predictions[i] = raw_exp[i]/exp_sum;
     predictions[i] = (int) (real_predictions[i] * 256.0);
   }
}
