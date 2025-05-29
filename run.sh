#!/usr/bin/env bash

zig build
zig build run -- test.kw program
zig cc program.o -o program

./program
