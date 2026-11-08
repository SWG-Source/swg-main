#!/usr/bin/python3

from os import walk, path, makedirs
from subprocess import PIPE, Popen

def read_objects(objectdir):
	files = []

	for (dirname, dirnames, filenames) in walk(objectdir):
		for filename in filenames:
			filename = filename.replace('.iff', '')

			objfile = path.join(dirname, filename)
			objfile = objfile.replace("%s/" % objectdir, '')

			files.append(objfile)

	return files

questlistdir = './data/sku.0/sys.shared/compiled/game/datatables/questlist'

allobjs = []

allobjs.extend(read_objects(questlistdir))

allobjs.sort()

tabfile = './dsrc/sku.0/sys.shared/built/game/misc/quest_crc_string_table.tab'
ifffile = './data/sku.0/sys.shared/built/game/misc/quest_crc_string_table.iff'

if not path.exists(path.dirname(tabfile)):
	makedirs(path.dirname(tabfile))

if not path.exists(path.dirname(ifffile)):
	makedirs(path.dirname(ifffile))

crc_call = ['./tools/buildCrcStringTable.pl',  '-t', tabfile, ifffile]

p = Popen(crc_call, stdin=PIPE, stdout=PIPE)

for obj in allobjs:
	p.stdin.write('{}\n'.format(obj).encode('utf-8'))

p.communicate()
