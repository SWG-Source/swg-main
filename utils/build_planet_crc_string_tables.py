#!/usr/bin/python3

from os import path, makedirs
from subprocess import PIPE, Popen

inputfile = './dsrc/sku.0/sys.shared/compiled/game/misc/planet_crc_string_table.txt'
ifffile = './data/sku.0/sys.shared/compiled/game/misc/planet_crc_string_table.iff'

if not path.exists(path.dirname(ifffile)):
	makedirs(path.dirname(ifffile))

crc_call = ['./tools/buildCrcStringTable.pl', ifffile, inputfile]

p = Popen(crc_call, stdin=PIPE, stdout=PIPE)

p.communicate()
