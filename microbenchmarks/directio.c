#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/time.h>

#include "helper.h"

#define ITERATIONS (1000)
#define DISK ("/dev/stripe/st0")

int
main(int argc, char *argv[])
{
	struct timeval tstart, tend;
	size_t transaction_size;
	ssize_t ret;
	char *buf;
	int fd;

	if (argc != 2) {
		fprintf(stderr, "./directio <TRANSACTION SIZE BYTES>\n");
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

	fd = open(DISK, O_RDWR);
	if (fd < 0) {
		perror("open");
		return (-1);
	}

	gettimeofday(&tstart, NULL);
	for (int i = 0; i < ITERATIONS; i++) {
		ret = pwrite(fd, buf, transaction_size, i * transaction_size);
		if (ret < 0) {
			perror("pwrite");
			return (-1);
		}

		if (ret != transaction_size) {
			fprintf(stderr, "ret %ld\n", ret);
			return (-1);
		}
	}

	gettimeofday(&tend, NULL);

	stats(microtime(&tstart, &tend) / ITERATIONS, transaction_size);

	close(fd);

	return (0);
}
