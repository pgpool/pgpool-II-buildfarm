#include <sys/shm.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/ipc.h>
#include <sys/shm.h>

main()
{
#define IPCProtection	(0600)	/* access/modify by user only */

	size_t size = 128*1024*1024;
	int shmid;

	shmid = shmget(IPC_PRIVATE, size, IPC_CREAT | IPC_EXCL | IPCProtection);
	if (shmid < 0)
	{
		fprintf(stderr, "shmget failed: %s\n", strerror(errno));
	}
	else
	{
		printf("%d shared memory successfully got. id: %d\n",size, shmid);
		if (shmctl(shmid, IPC_RMID, NULL) < 0)
		{
			fprintf(stderr, "removing shm %d failed: %s\n", shmid, strerror(errno));
		}
	}
}
