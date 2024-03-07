#!/usr/local/bin/python

from pathlib import Path
import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
import os
import random
from statistics import stdev
import sys

def dtrace_iter(valuefile, config):
    if not os.path.exists(valuefile):
        return
    
    # avg, sttddev, min, max
    results = dict()
    with open(valuefile) as f:
        for line in f.readlines():
            if len(line.strip()) == 0:
                continue
            name, value = line.split()
            config[name] = value

def plot(conf):
    fig, ax = plt.subplots(figsize=(8,8))
    fig.suptitle("DTrace operation latencies (in ns) and counts")
    fig.patch.set_visible(False)
    ax.axis("off")
    ax.axis("tight")

    allkeys = set()
    for key in conf.keys():
        for elem in conf[key].keys():
            allkeys.add(elem)

    header = sorted(allkeys)
    keys = sorted(map(int, list(conf.keys())))
    table = []
    for key in keys:
        row = []
        for op in header:
            if op not in conf[key]:
                row.append("N/A")
            else:
                row.append(conf[key][op])
        table.append(row)

    ax.table(cellText=table, rowLabels=keys, colLabels=header, loc="center", cellLoc="center", fontsize=14)

    fig.tight_layout()
    fig.savefig(Path.cwd() / "report-dtrace.pdf")


def fill_config(datadir):
    config = dict()

    for dirname in os.listdir(datadir):
        name = dirname.split("-")

        transaction_size = int(name[2])
        if transaction_size in config:
            continue
        config[transaction_size] = dict()
        conf = config[transaction_size] 

        slsname = "-".join([ "slsdb", "aurora", name[2]])
        basename = "-".join([ "slsdb", "baseline", name[2]])
        slsdbname = "-".join([ "slsdb", "slsdb", name[2]])

        slsfile = Path.cwd() / datadir / slsname / "dtrace.0"
        basefile = Path.cwd() / datadir / basename / "dtrace.0"
        slsdbfile = Path.cwd() / datadir / slsdbname / "dtrace.0"
        dtrace_iter(slsfile, conf)
        dtrace_iter(basefile, conf)
        dtrace_iter(slsdbfile, conf)

    for transaction_size in config:
        conf = config[transaction_size]
        for key in conf:
            if key.endswith("-count"):
                continue

    plot(config)

    return config


def sqlite_graph(datadir):
    conf = fill_config(datadir)
    #report_dtrace(conf)

if __name__ == "__main__":
    sqlite_graph(sys.argv[1])
