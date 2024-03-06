#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/mman.h>
#include <sys/time.h>

#include "helper.h"

#define DBSIZE (1024 * MB)
#define CKPT_SIZE (4 * MB)
#define ITERATIONS (1000)
#define PATH ("/testmnt/tmpfile")

char buf[PAGESIZE];

int
main(int argc, char *argv[])
{
	struct timeval tstart, tend;
	size_t ckpt_size, sync_time;
	size_t writes;
	ssize_t ret;
	size_t off;
	bool dirty;
	int error;
	char *db;
	int fd;

	if (argc != 2 && argc != 3) {
		fprintf(stderr, "./fsync <CHECKPOINT SIZE BYTES>\n");
		return (-1);
	}

	dirty = (argc == 3);

	ckpt_size = strtoul(argv[1], NULL, 10);
	if (ckpt_size == 0) {
		fprintf(stderr, "./Invalid checkpoint size\n");
		return (-1);
	}

	fd = open(PATH, O_RDWR | O_CREAT);
	if (fd < 0) {
		perror("open");
		return (-1);
	}

	error = ftruncate(fd, DBSIZE);
	if (error != 0) {
		perror("ftruncate");
		return (-1);
	}

	db = mmap(NULL, DBSIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (db == NULL) {
		perror("mmap");
		return (-1);
	}

	if (dirty) {
		bzero(db, DBSIZE);
		error = fsync(fd);
		if (error != 0) {
			perror("fsync");
			return (-1);
		}
	}

	srand(17);

	for (int i = 0, written = 0; i < ITERATIONS; i++) {
		for (int j = 0; j < ckpt_size / PAGESIZE; j++) {
			off = (((rand() % DBSIZE) / PAGESIZE) * PAGESIZE);
			memcpy(&db[off], buf, PAGESIZE);
		}

		gettimeofday(&tstart, NULL);
		error = fsync(fd);
		if (error != 0) {
			perror("fsync");
			return (-1);
		}
		gettimeofday(&tend, NULL);
		sync_time += microtime(&tstart, &tend);
	}


	stats(sync_time / ITERATIONS, ckpt_size);

	close(fd);

	return (0);
}
