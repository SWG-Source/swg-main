#!/usr/bin/python3

from os import walk, path, makedirs
from subprocess import PIPE, Popen

serverdir = './data/sku.0/sys.server/compiled/game/object'
shareddir = './data/sku.0/sys.shared/compiled/game/object'

def read_objects(objectdir):
	files = []

	for (dirname, dirnames, filenames) in walk(objectdir):
		for filename in filenames:
			if '.iff' in filename:
				objfile = path.join(dirname, filename)
				objfile = objfile.replace(objectdir.split('/object')[0] + '/', '')

				files.append(objfile)

	return files

def build_table(type, objs):
	tabfile = "./dsrc/sku.0/sys.%s/built/game/misc/object_template_crc_string_table.tab" % (type)
	ifffile = "./data/sku.0/sys.%s/built/game/misc/object_template_crc_string_table.iff" % (type)

	if not path.exists(path.dirname(tabfile)):
		makedirs(path.dirname(tabfile))

	if not path.exists(path.dirname(ifffile)):
		makedirs(path.dirname(ifffile))

	crc_call = ['./tools/buildCrcStringTable.pl',  '-t', tabfile, ifffile]

	p = Popen(crc_call, stdin=PIPE, stdout=PIPE)

	for obj in sorted(objs):
		p.stdin.write('{}\n'.format(obj).encode('utf-8'))

	p.communicate()

serverobjs = []
sharedobjs = []
allobjs = []

serverobjs.extend(read_objects('./data/sku.0/sys.server/compiled/game/object'))
sharedobjs.extend(read_objects('./data/sku.0/sys.shared/compiled/game/object'))
sharedobjs.extend(read_objects('./data/sku.0/sys.server/compiled/game/object/creature/player'))

build_table('client', sharedobjs)

allobjs.extend(serverobjs)
allobjs.extend(sharedobjs)

build_table('server', list(set(allobjs)))
