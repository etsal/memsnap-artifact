.PHONY: all clean

all: checkpoint directio memsnap memsnap-old old sastrack wal memsnap-objsnap-combo parallel-sastrack parallel-combo

checkpoint: checkpoint.c
	clang -g -O2 -lpthread -lsls -o checkpoint checkpoint.c

directio: directio.c
	clang -g -O2 -o directio directio.c

memsnap: memsnap.c
	clang -g -O2 -lsls -o memsnap memsnap.c

old: old.c
	clang -g -O2 -o old old.c ../aurora-original/libsls/libsls.a

memsnap-old: memsnap-old.c
	clang -g -O2 -o memsnap-old memsnap-old.c ../aurora-original/libsls/libsls.a

sastrack: sastrack.c
	clang -g -O2 -lsls -o sastrack sastrack.c

memsnap-objsnap-combo: sastrack.c
	clang -g -O2 -losnap -lmsnp -DUSE_MSNP_OBJSNP -o memsnap-objsnap-combo sastrack.c

objsnap: objsnap.c
	clang -g -O2 -lmsnp -losnp -o memsnap memsnap.c

wal: wal.c
	clang -g -O2 -o wal wal.c

parallel-sastrack: parallel.c
	clang -g -O2 -lsls -o parallel-sastrack parallel.c

parallel-combo: parallel.c
	clang -g -O2 -losnap -lmsnp -DUSE_MSNP_OBJSNP -o parallel-combo parallel.c


clean:
	rm -rf checkpoint directio memsnap old sastrack wal memsnap-objsnap-combo
