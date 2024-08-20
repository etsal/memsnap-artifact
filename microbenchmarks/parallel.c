#include <sys/mman.h>
#include <sys/time.h>

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#ifndef USE_MSNP_OBJSNP
#include <slos.h>
#include <sls.h>
#include <sls_wal.h>
#include <slsfs.h>
#else
#include <memsnap.h>
#include <objsnap.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "helper.h"

#ifndef USE_MSNP_OBJSNP
#define PATH ("/testmnt/sasfile")
#else
#define PATH ("/memsnap/sasfile")
#endif

#define CKPT_SIZE (16 * KB)
#define SLICESIZE (16 * MB)
#define ITERATIONS (100)

size_t total_latency = 0;
size_t numthreads;
void *db = NULL;
size_t dbsize;
int fd = -1;

int 
create_mapping(char *name, void **mappingp)
{
	int error;
	int fd;

	error = slsfs_sas_create(name, dbsize);
	if (error != 0) {
		printf("slsfs_sas_create failed (error %d)\n", error);
		exit(1);
	}

	fd = open(name, O_RDWR, 0666);
	if (fd < 0) {
		perror("open");
		exit(1);
	}

	/* Create the first mapping. */
	error = slsfs_sas_map(fd, mappingp);
	if (error != 0) {
		printf("slsfs_sas_map failed\n");
		exit(1);
	}

	return (fd);
}

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
			memset(&db[off], rand(), PAGESIZE);
		}

		clock_gettime(CLOCK_REALTIME_PRECISE, &tstart);
		sas_trace_commit(fd);
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

	threads = malloc(numthreads * sizeof(*threads));
	assert(threads != NULL);

	srand(17);

	fd = create_mapping(PATH, &db);

	memset(db, (rand() % ('z' - 'a')) + 'a', dbsize);

	error = sas_trace_start(fd);
	if (error != 0) {
		printf("sas_trace_start failed\n");
		exit(1);
	}

	for (i = 0; i < numthreads; i++)
		pthread_create(&threads[i], NULL, worker, (void *)i);

	for (i = 0; i < numthreads; i++)
		pthread_join(threads[i], NULL);

	error = sas_trace_end(fd);
	if (error != 0) {
		printf("sas_trace_end failed\n");
		exit(1);
	}

	stats(total_latency / (numthreads * ITERATIONS), CKPT_SIZE);

	return (0);
}
