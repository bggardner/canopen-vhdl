#!/usr/bin/python3
"""Generates a MEM file

Can be used as a generic memory generator, but targeted for CANopen EDS files
to be sent via SDO

Run eds2mem.py -h for usage"""
import argparse
import math
from sys import argv

parser = argparse.ArgumentParser()
parser.add_argument("input_file", type=str, help="input file")
parser.add_argument("mem_file", type=str, help="output MEM file")
parser.add_argument("--word", nargs="?", const=True, default=7, type=int, help="Word size, in bytes")
parser.add_argument("--zlib", nargs="?", const=True, default=0, type=int, help="Compresses input_file using zlib with given level (0-9)")
args = parser.parse_args()

with open(args.input_file, "rb") as fp:
    data = fp.read()

if args.zlib > 0:
    import zlib
    before = len(data)
    data = zlib.compress(data, args.zlib)
    print("Compressed to {:.1f}%".format(len(data) / before * 100))

addr_format = "@{:0" + "{}".format(math.ceil(math.ceil(math.log(len(data), 2)) / 4)) + "X} "
data_format = "{:0{" + "{}".format(args.word * 2) + "}X}\n"

with open(args.mem_file, "w") as fp:
    fp.write("// Generated with " + " ".join(argv) + "\n")
    fp.write("// {} bytes valid\n".format(len(data)))
    for i in range(0, len(data), args.word):
        fp.write(addr_format.format(int(i / args.word)))
        for j in reversed(range(args.word)):
            if i+j >= len(data):
                b = 0
            else:
                b = data[i + j]
            fp.write("{:02X}".format(b))
        fp.write("\n")

print("{} written with {} bytes".format(args.mem_file, len(data)))
