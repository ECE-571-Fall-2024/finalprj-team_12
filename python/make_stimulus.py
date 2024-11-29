
from keras.datasets import mnist
from random import randrange
import numpy


def make_digit_file():

  # load data
  (x_train, y_train), (x_test, y_test) = mnist.load_data()

  #combine all images and labels 

  images = numpy.concatenate((x_train, x_test));
  labels = numpy.concatenate((y_train, y_test));

  # select 20 images at random and put them in the file 'testbench_digits.bin'

  f = open("../data/testbench_digits.bin", "wb");

  for _ in range(20):
    index = randrange(images.shape[0]);
    f.write(images[index]);
    f.write(labels[index]);
    print("label: ", labels[index]);


if __name__ == '__main__':
  make_digit_file()

