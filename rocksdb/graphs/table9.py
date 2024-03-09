#!/usr/local/bin/python

import matplotlib.pyplot as plt
import os
from pathlib import Path
import sys

def getfloat(line, index):
    return float(line.strip().split()[index])

def getint(line, index):
    return int(line.strip().split()[index])

def metrics_iter(dfile):
    # ops, avg, median, p50, p99, p999
    results = []
    results_found = False
    with open(dfile) as f:
        lines = f.readlines()
        for i, l in enumerate(lines):
            if "Microseconds per write" in l:
                if results_found:
                    tmp = lines[i+1:i+4]

                    avg = getfloat(tmp[0], 3)
                    p50 = getfloat(tmp[2], 2)
                    p99 = getfloat(tmp[2], 6)
                    p999 = getfloat(tmp[2], 8)
                    results += [avg, p99]
                else:
                    results_found = True
            if "mixgraph" in l:
                ops = getint(l, 4)
                results = [ops] + results
    if results == []:
        print("WARNING: {} IS MALFORMED".format(valuefile))

    return results

def tonum(value):
    return round(float(value) / 1000, 1)

def toSI(value):
    if value < 1000:
        return str(value)
    if value < 1000 * 1000:
        return str("{:.1f}K".format(value / 1000))
    return str("{:.1f}M".format(value / (1000 * 1000)))


def fill_config(datadir):
    conf = dict()

    for dirname in os.listdir(datadir):
        name = dirname.split("-")[1]
        dfile = Path.cwd() / datadir / dirname / "0.out"
        conf[name] = metrics_iter(dfile)

    return conf

def metrics(datadir):
    data = fill_config(datadir)

    titles = ["\code{memsnap}", "Baseline+WAL", "\code{Aurora}"]
    confs = ["slsdb", "compact", "aurora"]
    for (conf, title) in zip(confs, titles):
        print(r"{\bf " + title + "} & ", end="")
        (kops, avg, tail) = data[conf]

        # XXX Formatting
        print(str(tonum(kops)) + r" & ", end="")
        print(toSI(avg) + r" & ", end="")
        print(toSI(tail) + r" \\")


def header():
    print(r"\begin{tabular}{@{} c | c c c @{}}")
    print(r"\toprule")
    print(r"&  \multicolumn{3}{c}{Metric} \\")
    print(r"{\bf Configuration} & {\bf Kops/s} & {\bf Avg(us)} & {\bf 99th(us)}\\ ")
    print(r"\midrule")


def footer():
    print(r"\bottomrule")
    print(r"\end{tabular}")


def sqlite_graph(datadir):
    conf = fill_config(datadir)

if __name__ == "__main__":
    header()
    metrics(Path("..") /  "data" / "rocksdb-artifact")
    footer()


