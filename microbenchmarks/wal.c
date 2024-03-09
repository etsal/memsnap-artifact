#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/time.h>

#include "helper.h"

#define ITERATIONS (1000)
#define PATH ("/testmnt/tmp")

int
main(int argc, char *argv[])
{
	size_t transaction_size, sync_time = 0;
	struct timeval tstart, tend;
	ssize_t ret;
	int error;
	char *buf;
	int fd;

	if (argc != 2) {
		fprintf(stderr, "./fsync <TRANSACTION SIZE BYTES>\n");
		return (-1);
	}

	transaction_size = strtoul(argv[1], NULL, 10);
	if (transaction_size == 0) {
		fprintf(stderr, "./Invalid transaction size\n");
		return (-1);
	}

	buf = malloc(transaction_size);
	if (buf == NULL) {
		perror("malloc");
		return (-1);
	}

	fd = open(PATH, O_RDWR | O_CREAT);
	if (fd < 0) {
		perror("open");
		return (-1);
	}

	for (int i = 0; i < ITERATIONS; i++) {
		gettimeofday(&tstart, NULL);
		ret = pwrite(fd, buf, transaction_size, i * transaction_size);
		if (ret < 0) {
			perror("pwrite");
			return (-1);
		}

		if (ret != transaction_size) {
			fprintf(stderr, "ret %ld\n", ret);
			return (-1);
		}

		error = fsync(fd);
		if (error != 0) {
			perror("fsync");
			return (-1);
		}
		gettimeofday(&tend, NULL);

		sync_time += microtime(&tstart, &tend);
	}

	stats(sync_time / ITERATIONS, transaction_size);

	close(fd);

	return (0);
}
