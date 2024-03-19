#!/usr/bin/env python

from pathlib import Path
import math
import os
from statistics import stdev
import sys

import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
import numpy as np
matplotlib.rcParams.update({'font.size': 9})
matplotlib.rcParams.update({'font.serif': "Times"})

ARTIFACT_DIR="sqlite-batch-artifact"

metrics = ["min", "50th", "90th", "99th", "avg", "stddev" ]

def sqlite_iter(valuefile):
    # avg, sttddev, min, max
    results = dict()
    with open(valuefile) as f:
        lines = f.readlines()
        writeresults = None
        readresults = None
        for i, l in enumerate(lines):
            if l.split(" ")[0] != "Microseconds":
                continue

            r = []
            if int(lines[i + 1].split()[1]) != 0:

                # Min
                row = lines[i + 2].split()
                r += [ float(row[1]) ]

                # 50th, 90th, and 99th percentile
                row = lines[i + 3].split()
                r += [ float(row[1]), float(row[3]), float(row[5]) ]
            
                # Average and stddev
                row = lines[i + 1].split()
                r += [ float(row[3]), float(row[5]) ]
            if writeresults is None:
                writeresults = r
            else:
                readresults = r

    return writeresults


def fill_config(datadir, bench, name):
    config = dict()

    for dirname in [d for d in os.listdir(datadir) if bench in d]:
        if dirname.split("-")[0] != name:
            continue

        transaction_size = dirname.split("-")[2]
        datafile = Path.cwd() / datadir / dirname / "0.out"
        config[transaction_size] = sqlite_iter(datafile)

    return config


def generate_metric(path, xvals, sls, slsstd, baseline, basestd, legend, si):
    fig, ax = plt.subplots(1, 1, figsize=(1.8, 1.4))
    colors = ["orange", "blue"]

    for tick in ax.get_xticklabels():
        tick.set_rotation(6)
        tick.set_rotation(45)
        tick.set_size(6)
    for tick in ax.get_yticklabels():
        tick.set_rotation(45)
        tick.set_size(6)
    ax.xaxis.label.set_size(6)
    ax.yaxis.label.set_size(6)

    xaxis = [str(x) for x in map(lambda x: x * 4, xvals)]
    if slsstd:
        ax.errorbar(xaxis, sls, yerr=slsstd, label="MemSnap", color=colors[1])
        ax.errorbar(xaxis, baseline, yerr=basestd, label="Baseline", color=colors[0])
    else:
        ax.plot(xaxis, sls, label="MemSnap", color=colors[1])
        ax.plot(xaxis, baseline, label="Baseline", color=colors[0])

    ax.set_ylabel("Latency ({})".format(si), fontsize=9)
    ax.set_xlabel("Transaction Size (KiB)", fontsize=9)
    if legend:
        ax.legend(ncol=2, fontsize=6, bbox_to_anchor=(0.99, 0.98), bbox_transform=fig.transFigure)

    _, top = ax.get_ylim()
    top = 10 ** (math.ceil(math.log10(top)))
    ax.set_ylim((1, top))
    ax.set_yscale("log")

    fig.tight_layout()
    fig.savefig("{}.png".format(path))


def metrics_pgf(bench):
    confbase = fill_config(Path.cwd().parent / "data" / ARTIFACT_DIR, bench, "baseline")
    confsls = fill_config(Path.cwd().parent / "data"/ ARTIFACT_DIR, bench, "sls")

    xvals = sorted(map(int, confsls.keys()))
    stdindex = metrics.index("stddev")
    slsstddev = [ confsls[str(xval)][stdindex] / 1000 for xval in xvals ]
    basestddev = [ confbase[str(xval)][stdindex] / 1000 for xval in xvals ]

    for metric in [ "avg", "99th" ]:
        index = metrics.index(metric)
        sls = [ confsls[str(xval)][index] / 1000 for xval in xvals ]
        base = [ confbase[str(xval)][index] / 1000 for xval in xvals ]

        slsstd = slsstddev if metric == "avg" else None
        basestd = basestddev if metric == "avg" else None
        
        legend = bench == "fillrandbatch" and metric == "avg"
        path = Path.cwd() / "pgfs" / "eval-total-{}-{}".format(bench, metric)
        si = "ms"
        generate_metric(path, xvals, sls, slsstd, base, basestd, legend, si)

if __name__ == "__main__":
    for bench in [ "fillrandbatch", "fillseqbatch" ]:
        metrics_pgf(bench)
