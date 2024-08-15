#include <sys/mman.h>
#include <sys/time.h>

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
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

#define PATH ("/testmnt/sasfile")

#define DBSIZE (256 * MB)
#define ITERATIONS (100)

int 
create_mapping(char *name, void **mappingp)
{
	int error;
	int fd;

	error = slsfs_sas_create(name, DBSIZE);
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

int
main(int argc, char **argv)
{
	size_t ckpt_size, sync_time = 0;
	struct timespec tstart, tend;
	uint64_t nextepoch;
	size_t total_time;
	size_t time;
	size_t off;
	int error;
	int fd;
	void *db;

	if (argc != 2) {
		printf("./sastrack <size>\n");
		return (-1);
	}

	ckpt_size = strtoul(argv[1], NULL, 10);
	if (ckpt_size == 0) {
		fprintf(stderr, "./Invalid checkpoint size\n");
		return (-1);
	}

	srand(17);

	fd = create_mapping(PATH, &db);

	memset(db, (rand() % ('z' - 'a')) + 'a', DBSIZE);

	error = sas_trace_start(fd);
	if (error != 0) {
		printf("sas_trace_start failed\n");
		exit(1);
	}

	/* Snapshot and return an error. */
	for (int i = 0; i < ITERATIONS; i++) {
		for (int j = 0; j < ckpt_size / PAGESIZE; j++) {
			off = (((rand() % DBSIZE) / PAGESIZE) * PAGESIZE);
			memset(&db[off], rand(), PAGESIZE);
		}

		clock_gettime(CLOCK_REALTIME_PRECISE, &tstart);
		sas_trace_commit(fd);
		clock_gettime(CLOCK_REALTIME_PRECISE, &tend);

		sync_time += (nanotime(&tstart, &tend) / 1000);
	}

	stats(sync_time / ITERATIONS, ckpt_size);
	
	error = sas_trace_end(fd);
	if (error != 0) {
		printf("sas_trace_end failed\n");
		exit(1);
	}

	return (0);
}
