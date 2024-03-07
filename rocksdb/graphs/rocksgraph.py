#!/usr/bin/env python

from pathlib import Path
import matplotlib.pyplot as plt
import os
from statistics import stdev

metrics = ["ops", "avg", "p50", "p99", "p999" ]

def getint(line, index):
    return int(line.strip().split()[index])

def getfloat(line, index):
    return float(line.strip().split()[index])

def rocksdb_iter_file(valuefile):
    # ops, avg, median, p50, p99, p999
    results = []
    results_found = False
    with open(valuefile) as f:
        lines = f.readlines()
        for i, l in enumerate(lines):
            if "Microseconds per write" in l:
                if results_found:
                    tmp = lines[i+1:i+4]

                    avg = getfloat(tmp[0], 3)
                    p50 = getfloat(tmp[2], 2)
                    p99 = getfloat(tmp[2], 6)
                    p999 = getfloat(tmp[2], 8)
                    results += [avg, p50, p99, p999]
                else:
                    results_found = True
            if "mixgraph" in l:
                ops = getint(l, 4)
                results = [ops] + results
    if results == []:
        print("WARNING: {} IS MALFORMED".format(valuefile))
    return results

def rocksdb_iter_subdir(subdir, metric):
    files = os.listdir(subdir)
    data = [ rocksdb_iter_file(subdir / file) for file in files if file.split(".")[0].isnumeric()]
    data = [ d for d in data if d != [] ]
    results = []
    for i, m in enumerate(metrics):
        if metric != m:
            continue

        rawvals = [ datum[i] for datum in data ]
        if len(rawvals) == 0:
            print("WARNING: NO DATA POINTS FOR {}, USING (0, 0)".format(subdir))
            return (0, 0)
        elif len(rawvals) == 1:
            return (sum(rawvals) / len(rawvals), 0)
        else:
            return (sum(rawvals) / len(rawvals), stdev(rawvals))

    raise Exception("Metric {} not found".format(metric))

def rocksdb_config(basedir, configname, metric, sizes):
    subdirs = reversed(sorted([ d for d in list(os.listdir(basedir)) if d.split("-")[1] == configname ]))
    subdirs = [ d for d in subdirs if int(d.split("-")[2]) in sizes ]
    results = [ rocksdb_iter_subdir(basedir / subdir, metric) for subdir in subdirs]

    yval = [result[0] for result in results]
    yerr = [result[1] for result in results]

    return (yval, yerr)

def sizetobytes(size):
    if size >= 40:
        raise Exception("Value too large")

    if size < 10:
        return "{}B".format(2**int(size))
    if size < 20:
        return "{}KB".format(2**(int(size) - 10))
    if size < 30:
        return "{}MB".format(2**(int(size) - 20))
    return "{}GB".format(2**(int(size) - 30))
