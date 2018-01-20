#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char** argv)
{
	if (argc != 2)
	{
		printf("syntax: \"%s search_string\"\n", argv[0]);
		printf("example: \"%s SwgGameServer:15433 < profile.txt > chilastra_profile_restuss.txt\"\n", argv[0]);
		printf("example: \"%s handleFX < profile.txt > handleFX_profile.txt\"\n", argv[0]);
		return 0;
	}

	char * buffer[32768];
	for (int i = 0; i < 32768; ++i)
		buffer[i] = reinterpret_cast<char*>(malloc(512));

	bool found = false;
	int bufferIndex = 0;
	while (gets(buffer[bufferIndex]))
	{
		if (strstr(buffer[bufferIndex], argv[1]))
		{
			found = true;
		}

		if (strlen(buffer[bufferIndex]) > 0)
		{
			++bufferIndex;
		}
		else
		{
			if (found)
			{
				for (int i = 0; i < bufferIndex; ++i)
				{
					printf("%s\n", buffer[i]);
				}

				printf("\n");
			}

			found = false;
			bufferIndex = 0;
		}

		if (bufferIndex >= 32768)
		{
			printf("ERROR! Profile block exceeds 32768 lines\n");
			found = false;
			break;
		}
	}

	if (found)
	{
		for (int i = 0; i < bufferIndex; ++i)
		{
			printf("%s\n", buffer[i]);
		}

		printf("\n");
	}

	for (int i = 0; i < 32768; ++i)
		free(buffer[i]);

	return 0;
}
