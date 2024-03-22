#!/usr/local/bin/python

from pathlib import Path
import matplotlib.pyplot as plt
import os
import random
from statistics import stdev
import sys

def dtrace_iter(valuefile, conf):
    # avg, sttddev, min, max
    results = dict()
    with open(valuefile) as f:
        for line in f.readlines():
            if len(line.strip()) == 0:
                continue
            name, value = line.split()
            if not name.endswith("-count"):
                conf[name] = int(value)

def fill_config(datadir):
    confs = dict()
    for dirname in os.listdir(datadir):
        name = dirname.split("-")[1]

        conf = dict()

        dfile = Path.cwd() / datadir / dirname / "dtrace.0"
        dtrace_iter(dfile, conf)

        confs[name] = conf

    return confs


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
    aurora = data["aurora"] 
    memsnap = data["slsdb"]
    descriptions = [ "Waiting for Calls", "Applying COW", "Flush IO", "Removing COW", "Total"]
    aurora_results = [ aurora["enter"], aurora["cow"], aurora["write"], aurora["wait"] + aurora["cleanup"] ]
    memsnap_results = [ 0,  memsnap["protect"], memsnap["write"] + memsnap["block"], 0]

    aurora_row = list(map(lambda latency: tonum(latency), aurora_results))
    memsnap_row = list(map(lambda latency: tonum(latency), memsnap_results))

    aurora_row.append(sum(aurora_row))
    memsnap_row.append(sum(memsnap_row))

    for i, desc in enumerate(descriptions):

        print(r"{\bf \code{" + str(desc) + "} } & ", end="")

        print(toSI(memsnap_row[i]) + r" & ", end="")
        print(toSI(aurora_row[i]) + r" \\")

def header():
    print(r"\begin{tabular}{@{} c | c c @{}}")
    print(r"\toprule")
    print(r"&  \multicolumn{2}{c}{Time (us)} \\")
    print(r"{\bf Operation Call} & {\bf MemSnap} & {\bf Aurora} \\ ")
    print(r"\midrule")


def footer():
    print(r"\bottomrule")
    print(r"\end{tabular}")

if __name__ == "__main__":
    header()
    dtrace(Path.cwd() / ".." / "data" / "rocksdb-artifact")
    footer()

