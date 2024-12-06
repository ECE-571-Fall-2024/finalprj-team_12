import os
# this supresses annoying warning when tensorflow is loaded
os.environ['TF_CPP_MIN_LOG_LEVEL']='3'

# Baseline MLP for MNIST dataset
from keras.datasets import mnist
from keras.models import Sequential
from keras.layers import Dense, Conv2D, Flatten, MaxPooling2D, Input
from keras import utils
import numpy as np
import random

#===============================================================================#
# MNIST CNN definition                                                          #
# --------------------                                                          #
#                                                                               #
# Can be modified to increase or decrease number of layer, number of channels   #
# supported layers are Conv2D, Dense, and Flatten.  Suppoted kernel sizes are   #
# 3, 5, and 7, square kernels only                                              #
#                                                                               #
#===============================================================================#

def mnist_model():
  # create model
  model = Sequential()
  model.add(Input(shape=(28,28,1)))
  model.add(Conv2D(20, (5,5), use_bias=True, padding="same", activation='relu'))
  model.add(MaxPooling2D(pool_size=(2,2)))
  model.add(Conv2D(50, (3,3), use_bias=True, padding="same", activation='relu'))
  model.add(MaxPooling2D(pool_size=(2,2)))
  model.add(Flatten())
  #model.add(Dense(500, use_bias=True, kernel_initializer='normal', activation='relu'))
  model.add(Dense(20, use_bias=True, kernel_initializer='normal', activation='relu'))
  model.add(Dense(10, use_bias=True, kernel_initializer='normal', activation='softmax'))
  # Compile model
  model.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy'])
  return model


#===============================================================================#
# Create and train the MNIST CNN                                                #
# ------------------------------                                                #
#                                                                               #
# Default epochs is 10, batch_size is 200.  Increase epochs and batch size for  #
# better inferencing, 20 to 30 epochs is good for generating final weights      #
#                                                                               #
#===============================================================================#


def create_and_train(epochs=10, batch_size=200, verbose=1):

  # load data
  (X_train, y_train), (X_test, y_test) = mnist.load_data()

  X_train = X_train.reshape((X_train.shape[0], X_train.shape[1], X_train.shape[2], 1)).astype('int32');
  X_test = X_test.reshape((X_test.shape[0], X_test.shape[1], X_test.shape[2], 1)).astype('int32');

  # normalize inputs from 0-255 to 0-1
  X_train = X_train / 255
  X_test = X_test / 255

  # one hot encode outputs
  y_train = utils.to_categorical(y_train)
  y_test = utils.to_categorical(y_test)

  num_classes = y_test.shape[1]

  model = mnist_model()

  model.fit(X_train, y_train, validation_data=(X_test, y_test), epochs=epochs, batch_size=batch_size, verbose=verbose)
  scores = model.evaluate(X_test, y_test, verbose=0)
  print("Baseline Error: %.2f%%" % (100-scores[1]*100))
  return model

def print_mnist_image(image):
  local_image = image.reshape(28,28).copy()
  for row in range(28):
    for col in range(28):
      print('{:3d} '.format(int(local_image[row][col]*255.0)), end='')
    print(' ')
  print(' ')
