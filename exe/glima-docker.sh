#!/bin/sh

exec docker run -it --rm \
  -v $HOME/.config/glima:/root/.config/glima \
  -v $HOME/.cache/glima:/root/.cache/glima   \
  nom4476/glima "$@"
