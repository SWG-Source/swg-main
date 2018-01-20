
// Compile this with g++ -O6 -o CoreMemWalker CoreMemWalker.cpp -static

#include <sys/fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>

// ======================================================================

struct SystemAllocation
{
	int size;
	unsigned int next;
	int pad1, pad2;
};

struct AllocatedBlock
{
	// Block is 16 for debug build, 12 for release build (release build doesn't have array)
	unsigned int prev, next;
	bool free:1;
#ifdef _DEBUG
	bool array:1;
#endif
	bool leakTest:1;
	unsigned int size:30;

	// AllocatedBlock starts here
	unsigned int owner[64];
};

struct AddressOffset
{
	unsigned int s, e, o;
};

// ======================================================================

int ao_c = 0;
AddressOffset ao[1024];
char const *coreMem = 0;
unsigned int coreLen = 0;
const unsigned int MAX_MAP_SIZE = 2000000000;

// ======================================================================

bool mapCore(char const *coreName)
{
	int fd = open(coreName, O_RDONLY);
	if (fd != -1)
	{
		struct stat s;
		fstat(fd, &s);
		coreLen = s.st_size;
		if (coreLen > MAX_MAP_SIZE)
			coreLen = MAX_MAP_SIZE;
		coreMem = reinterpret_cast<char const *>(mmap(0, coreLen, PROT_READ, MAP_PRIVATE|MAP_NORESERVE, fd, 0));
		close(fd);
	}
	return coreMem && coreMem != ((char const *)MAP_FAILED) ? true : false;
}

// ----------------------------------------------------------------------

void unmapCore()
{
	if (coreMem)
		munmap(reinterpret_cast<void *>(const_cast<char *>(coreMem)), coreLen);
}

// ----------------------------------------------------------------------

bool loadMemoryMap(char const *mapName)
{
	FILE *fp = fopen(mapName, "r");
	if (fp)
	{
		unsigned int a, c, d, e, f;
		char b[512], g[512];
		while (fscanf(fp, "%d %s %x %x %x %x %s\n", &a, b, &c, &d, &e, &f, g) == 7)
		{
			ao[ao_c].s = d;
			ao[ao_c].e = d+c;
			ao[ao_c].o = f-d;
			++ao_c;
		}
		fclose(fp);
		return true;
	}
	return false;
}

// ----------------------------------------------------------------------

char const *getMem(unsigned int addr)
{
	for (int i = 0; i < ao_c; ++i)
		if (addr >= ao[i].s && addr < ao[i].e)
			return coreMem+addr+ao[i].o;
	return coreMem;
}

// ----------------------------------------------------------------------

int main(int argc, char **argv)
{
	if (argc != 5)
	{
		fprintf(stderr,
			"Usage: CoreMemWalker coreName mapName firstSystemAllocationAddr ownerCount\n"
			"  This is only meant to be used from the coreMemReport.sh script.\n");

		AllocatedBlock a;
		fprintf(stderr, "sizeof(AllocatedBlock)=%d, sizeof(AllocatedBlock) - owner=%d\n", sizeof(AllocatedBlock), sizeof(AllocatedBlock) - sizeof(a.owner));
		fprintf(stderr, "&AllocatedBlock=%p, sizeof=%d\n", &a, sizeof(a));
		fprintf(stderr, "&AllocatedBlock.prev=%p, sizeof=%d\n", &a.prev, sizeof(a.prev));
		fprintf(stderr, "&AllocatedBlock.next=%p, sizeof=%d\n", &a.next, sizeof(a.next));
		fprintf(stderr, "&AllocatedBlock.owner=%p, sizeof=%d\n", &a.owner, sizeof(a.owner));

		return 1;
	}
			
	char const *coreName = argv[1];
	char const *mapName = argv[2];
	unsigned int firstSystemAllocationAddr = atoi(argv[3]);
	unsigned int ownerCount = atoi(argv[4]);
//	int count = 0;

	if (   mapCore(coreName)
	    && loadMemoryMap(mapName))
	{
		unsigned int systemAllocationAddr = firstSystemAllocationAddr;
		while (systemAllocationAddr)
		{
			SystemAllocation const * const systemAllocation = reinterpret_cast<SystemAllocation const *>(getMem(systemAllocationAddr));
			AllocatedBlock const * const firstBlockForSA = reinterpret_cast<AllocatedBlock const *>(reinterpret_cast<char const *>(systemAllocation)+16);
			AllocatedBlock const * const lastBlockForSA = reinterpret_cast<AllocatedBlock const *>(reinterpret_cast<char const *>(systemAllocation)+systemAllocation->size-16);
			unsigned int blockAddr = firstBlockForSA->next;
			AllocatedBlock const *block = reinterpret_cast<AllocatedBlock const *>(getMem(blockAddr));
			while (block != lastBlockForSA)
			{
				if (!block->free)
				{
					printf("0x%x %d", blockAddr, block->size);
					for (int i = 0; i < ownerCount; ++i)
						printf(" 0x%x", block->owner[i]);
					printf("\n");

//					++count;
//					printf("%d\n", count);

//					if (count > 2153024)
//						break;
				}
				if (blockAddr == block->next)
					break;
				blockAddr = block->next;
				block = reinterpret_cast<AllocatedBlock const *>(getMem(blockAddr));
			}

//			if (count > 2153024)
//				break;

			if (systemAllocationAddr == systemAllocation->next)
				break;
			systemAllocationAddr = systemAllocation->next;
		}
		unmapCore();
	}

	return 0;
}

