#!/bin/sh

glslc shaders/shader.vert -o builds/vert.spv
glslc shaders/shader.frag -o builds/frag.spv
