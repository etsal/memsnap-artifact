#ifndef _HELPER_H_
#define _HELPER_H_

#define M_NS (1000 * 1000 * 1000)
#define M_US (1000 * 1000)
#define KB (1024)
#define MB (1024 * 1024)
#define PAGESIZE (4096)

static inline unsigned long 
tvtomicro(struct timeval *tv)
{
	return (tv->tv_sec * M_US) + tv->tv_usec;
}

static inline unsigned long
microtime(struct timeval *tstart, struct timeval *tend)
{
	return (tvtomicro(tend) - tvtomicro(tstart));
}

static inline unsigned long 
tstonano(struct timespec *tv)
{
	return (tv->tv_sec * M_NS) + tv->tv_nsec;
}


static inline unsigned long
nanotime(struct timespec *tstart, struct timespec *tend)
{
	return (tstonano(tend) - tstonano(tstart));
}

static inline void
stats(double transaction_latency, size_t transaction_size)
{
	double normalized_latency, throughput;

	normalized_latency = transaction_latency / (transaction_size / PAGESIZE);
	throughput = PAGESIZE / ((normalized_latency / M_US) * MB);

	/*
	printf("TX op size\t%ld KB\n", transaction_size / KB);
	printf("Transaction\t%.02f us\n", transaction_latency);
	printf("Normalized4K\t%.02f us\n", normalized_latency);
	printf("Throughput\t%.02f MB\n", throughput);
	*/
	printf("%.02f us\t", transaction_latency);
}

#endif /* _HELPER_H_ */
