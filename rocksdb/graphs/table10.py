#!/usr/local/bin/python

from pathlib import Path
import matplotlib.pyplot as plt
import os
import random
from statistics import stdev
import sys

def dtrace_iter(valuefile, times, counts):
    # avg, sttddev, min, max
    results = dict()
    with open(valuefile) as f:
        for line in f.readlines():
            if len(line.strip()) == 0:
                continue
            name, value = line.split()
            if name.endswith("-count"):
                counts[name.split("-")[0]] = int(value)
            else:
                times[name] = int(value)

def fill_config(datadir):
    conf = dict()

    for dirname in os.listdir(datadir):
        name = dirname.split("-")

        counts = dict()
        times = dict()

        dfile = Path.cwd() / datadir / dirname / "dtrace.0"
        dtrace_iter(dfile, times, counts)

        for key in times:
            conf[key] = (times[key], counts[key])

    return conf


def tonum(value):
    return round(float(value) / 1000, 1)

def toSI(value):
    if value < 1000:
        return str(value)
    if value < 1000 * 1000:
        return str("{:.1f}K".format(value / 1000))
    return str("{:.1f}M".format(value / (1000 * 1000)))

def dtrace(datadir):
    data = fill_config(datadir)
    ops = ["memsnap", "fsync", "write", "checkpoint"]
    for op in ops:
        print(r"{\bf \code{" + str(op) + "} } & ", end="")
        (latency, times) = data[op]

        # XXX Formatting
        print(toSI(tonum(latency)) + r" & ", end="")
        print(toSI(times) + r" \\")

def header():
    print(r"\begin{tabular}{@{} c | c c @{}}")
    print(r"\toprule")
    print(r"&  \multicolumn{2}{c}{Metrics} \\")
    print(r"{\bf System Call} & {\bf Latency (us)} & {\bf Total Count} \\ ")
    print(r"\midrule")


def footer():
    print(r"\bottomrule")
    print(r"\end{tabular}")


def sqlite_graph(datadir):
    conf = fill_config(datadir)

if __name__ == "__main__":
    header()
    dtrace(Path.cwd() / ".." / "data" / "rocksdb-artifact")
    footer()

