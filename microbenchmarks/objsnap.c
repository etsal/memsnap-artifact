#include <sys/mman.h>
#include <sys/time.h>

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <objsnap.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "helper.h"

#define PATH ("/memsnap/sasfile")

#define CKPT_SIZE (16 * KB)
#define SLICESIZE (16 * MB)
#define ITERATIONS (100)

size_t total_latency = 0;
size_t numthreads;
void *db = NULL;
size_t dbsize;
size_t inode = -1;

void *
worker(void *arg)
{
	struct timespec tstart, tend;
	size_t slice = (size_t)arg;
	size_t sync_time = 0;
	size_t offset;
	size_t off;

	/* Snapshot and return an error. */
	for (int i = 0; i < ITERATIONS; i++) {
		for (int j = 0; j < CKPT_SIZE / PAGESIZE; j++) {
			offset  = (slice * SLICESIZE) + (rand() % SLICESIZE);
			off = ((offset / PAGESIZE) * PAGESIZE);
			objsnap_dirty(inode, slice, &db[off]);
		}

		clock_gettime(CLOCK_REALTIME_PRECISE, &tstart);
		objsnap_checkpoint(slice);
		clock_gettime(CLOCK_REALTIME_PRECISE, &tend);

		sync_time += (nanotime(&tstart, &tend) / 1000);
	}

	__atomic_fetch_add(&total_latency, sync_time, __ATOMIC_SEQ_CST);

	pthread_exit(NULL);
}

int
main(int argc, char **argv)
{
	pthread_t *threads;
	uint64_t nextepoch;
	size_t total_time;
	size_t time;
	int error;
	int i;

	if (argc != 2) {
		printf("./parallel <numthreads>\n");
		return (-1);
	}

	numthreads = strtoul(argv[1], NULL, 10);
	if (numthreads == 0) {
		fprintf(stderr, "./Invalid number of threads\n");
		return (-1);
	}
	dbsize = numthreads * SLICESIZE;
	db = mmap(NULL, dbsize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	assert(db != NULL);

	threads = malloc(numthreads * sizeof(*threads));
	assert(threads != NULL);

	srand(17);

	inode = objsnap_create();

	memset(db, (rand() % ('z' - 'a')) + 'a', dbsize);

	for (i = 0; i < numthreads; i++)
		pthread_create(&threads[i], NULL, worker, (void *)i);

	for (i = 0; i < numthreads; i++)
		pthread_join(threads[i], NULL);

	stats(total_latency / (numthreads * ITERATIONS), CKPT_SIZE);
	
	return (0);
}
