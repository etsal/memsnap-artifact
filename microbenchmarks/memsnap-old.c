#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../aurora-original/include/sls.h"
#include "helper.h"

#define ITERATIONS (10)
#define OID (2358)

int
checkpoint(void)
{
	struct sls_attr attr;
	uint64_t nextepoch;
	size_t off;
	int error;
	
	attr = (struct sls_attr) {
		.attr_target = SLS_OSD,
		.attr_mode = SLS_DELTA,
		.attr_period = 0,
		.attr_flags = 0,
	};

	error = sls_partadd(OID, attr);
	if (error != 0) {
		fprintf(stderr, "sls_partadd %d\n", error);
		return (-1);
	}

	/* Attach ourselves to the partition. */
	error = sls_attach(OID, getpid());
	if (error != 0)
		return (-1);

	/* Do a full checkpoint. */
	error = sls_checkpoint_epoch(OID, false, &nextepoch);
	if (error != 0)
		return (-1);

	error = sls_untilepoch(OID, nextepoch);
	if (error != 0) {
		fprintf(stderr, "sls_untilepoch: %s\n", strerror(error));
		return (-1);
	}

	return (0);
}

int
main(int argc, char **argv)
{
	struct timespec tstart, tend;
	size_t ckpt_size, sync_time;
	uint64_t nextepoch;
	size_t total_time;
	size_t time;
	size_t off;
	int error;
	void *db;

	if (argc != 2 && argc != 3) {
		printf("./memsnap <size> [block]\n");
		return (-1);
	}

	ckpt_size = strtoul(argv[1], NULL, 10);
	if (ckpt_size == 0) {
		fprintf(stderr, "./Invalid checkpoint size\n");
		return (-1);
	}

	srand(17);

	db = mmap((void *)0x100000000, ckpt_size, PROT_READ | PROT_WRITE,
	    MAP_FIXED | MAP_ANON | MAP_PRIVATE, -1, 0);
	if (db == MAP_FAILED) {
		perror("mmap");
		return (-1);
	}

	memset(db, rand(), ckpt_size);

	error = checkpoint();
	if (error != 0)
		return (error);

	sleep(2);

	/* Snapshot and return an error. */
	for (int i = 0; i < ITERATIONS; i++) {
		memset(db, rand(), ckpt_size);

		clock_gettime(CLOCK_REALTIME_PRECISE, &tstart);
		error = sls_memsnap_epoch(OID, db, &nextepoch);
		if (error != 0)
			return (-1);
		clock_gettime(CLOCK_REALTIME_PRECISE, &tend);

		error = sls_untilepoch(OID, nextepoch);
		if (error != 0) {
			fprintf(stderr, "sls_untilepoch: %s\n", strerror(error));
			return (-1);
		}
		sync_time += (nanotime(&tstart, &tend) / 1000);
	}

	stats(sync_time / ITERATIONS, ckpt_size);

	return (0);
}
