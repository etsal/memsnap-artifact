ARTIFACT EVALUATION FOR MEMSNAP
===============================


This is the main artifact repository for the paper "MemSnap: A Data Single Level Store for Fearless Persistence". This repository includes the main MemSnap system and benchmarks used in the paper.


Contents
--------

The structure of the repository is as follows:

- util.sh: Bash utility functions common to all benchmarks.
- microbenchmarks: Microbenchmarks for evaluating MemSnap's COW and checkpointing capabilities. Generates Figures 1 and 2, and Tables 5 and 6.
- sqlite: The SQLite database benchmarks, dbbench and TATP. Generates Figures 3 and 4, and Tables 7 and 8.
- rocksdb: The RocksDB dbbench benchmark. Generates tables 2, 9 and 10 (Table 2 is a subset of Table 10).
- postgres: The PostgreSQL TPCC benchmakr. Generates Figure 5.

- aurora-memsnap: The MemSnap repository. MemSnap is a microcheckpoint design that builds on top of the initial Aurora single levle store code.
- aurora-original: The original Aurora single level store code (SOSP 2021). Includes bugfixes and a patch that adapts it from FreeBSD 12.1 to FreeBSD 12.3.

- FlameGraph: Dependency for the graph creation scripts.
- loader.conf: Local sysctls for the systems.
- packages: FreeBSD 12.3 package dependencies necessary for the benchmarks to run. They are installed during setup.
- README.md: This file.

Setting Up
----------

WARNING: The MemSnap scripts require two dedicated disks to function properly. These are normally called vtbd1 and vtbd2 if the machine is a virtual machinme, or nvd0 and nvd1 for NVMe drives on a physical machine. You must specify the names of the two disks in ~/.profile, like so:

```
export DISK1="<diskname>"
export DISK2="<diskname>"
```

The setup process for the artifact involves 3 steps:

- setup.sh: Initial setup for the local machine. The script sets environment variables and install dependencies required by the benchmarks.
- buildkernel.sh: Building the modified FreeBSD kernel required by Aurora. This script downloads the tree, places it in the correct location, compiles it and installs it.
- Reboot the system. The system will come back running the new kernel.
- buildtests.sh: Compile and run MemSnap and its benchmarks. The script first compiles both Aurora and MemSnap. It then compiles the microbenchmarks, SQLite, RocksDB, and Postgres. After the script completes, the system is ready for benchmakbenchmarkring.

Running the Benchmarks
----------------------

1) To run the microbenchmarks, go to directory microbenchmarks and run the following:

- figure1.sh: Prints out the results of Figure 1 (comparison of memory protection techniques between Aurora and MemSnap).
- figure2.sh: Prints out the results of Figure 2 (comparison of memory protection techniques between Aurora and MemSnap).
- table5.sh: Prints out Table 5 (Breakdown of the latency of MemSnap's persistence)
- table6.sh: Prints out Table 6 (Comparison of MemSnap to file-based persistence mechanisms)

2) To run SQLite, please go to the sqlite/ directory. The benchmark has already been compiled by buildtests.sh.

The first step is to generate the numbers to be used by the scripts using the following scripts:
- sqlite-batch.sh: Runs the SQLite dbbench benchmark. This benchmark takes a long time even on a powerful machine, but you can do shorter runs by adjusting the OPERATIONS variabile in the sqlite-batch.sh script to ensure that it works.
- sqlite-tatpsls.sh Runs the SQLite TATP benchmark. 

To generate the graphs and tables for the SQLite benchmakrs, go to sqlite/graphs and run the following commands. The PNGs are in sqlite/graphs/pgfs.

- setup.sh: Copies the numbers into the graphs directory to be used by the scripts.
- figure3.sh: Generates a PNG graph for Figure 3 (Comparison of baseline and MemSnap SQLite performance for dbbench) 
- figure4.sh: Generates a PNG graph for Figure 4 (Comparison of baseline and MemSnap SQLite performance for TATP)
- table7.sh: Prints out a table for Table 7 (Comparison between MemSnap microcheckpoints and the file API for 4KiB, 64KiB and 1024KiB transaction sizes)
- table8.sh: Prints out a table for Table 8 (CPU usage comparison between baseline and MemSnap SQlite for dbbench, 32KiB)

3) To run RocksDB, please go to the rocksdb/ directory. The benchmark has already been compiled by buildtests.sh. Running rocksdb-paper.sh will generate the numbers required by the graphing scripts. To generate the tables please go to rocksdb/graphs and run:

- table9a.sh: Prints out a table for Table 9a (Performance comparison between MemSnap-RocksDB, Aurora-RocksDB and baseline RocksDB for dbbench)
- table9b.sh: Prints out a table for Table 9b (DTrace breakdown of MemSnap and Aurora persistence operations)
- table10.sh: Prints out a table for Table 10, (Latency breakdown and comparison between the MemSnap and Aurora persistence operations under RocksDB). The second column printed out is Table 2.

3) To run PostGreSQL, please go to the postgres/ directory:
- Run ./setup.sh, this will create the required users (users and postgres) and clone the modified postgres repo required to run the benchmark.
- Modify the benchmark.sh to the proper disks (default is nvd0 and nvd1)
- Run ./benchmark.sh
- Data can be found in the data directory. FFS = ffs, FFS+m = ffs-mmap, FFS+m,bd = ffs-mmap-bufdirect, MemSnap = slsfs-latest. 
- Run ./graph.py - To generate tps.png (Fig 5a) lat.png (Fig 5b)
- Run ./rusage.py - To generate kibs.png (Fig 5c) iops.png (Fig 5d)
- Please note the graphs are not the exact same in style as we removed the latek packages they we typically used as the package was burdensome for the artifact.
- In the case of a crash, you should comment out the already succeeded benchmarks (they are broken up by seperate run commands) in the benchmark.sh file as to not constanty re-run already succeeded benchmarks. 
- Default number of iterations is 5, with each iteration taking 10-15 minutes. 4 Seperate major datapoints, means the benchmark could take up to 4-5 hours.
