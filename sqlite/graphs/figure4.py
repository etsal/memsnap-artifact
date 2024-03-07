#!/usr/bin/env python

from pathlib import Path
import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
import numpy as np
import os
import sys

def sqlite_iter(valuefile):
    with open(valuefile) as f:
        line = f.readline()
        return round(float(line.strip()))

def report_metrics(keys, basenums, slsnums):
    fig, ax = plt.subplots(1, 1)

    width = 0.25
    x = np.arange(len(keys))

    for i , (label, color, vals) in enumerate([("baseline", "orange", basenums), ("memsnap", "blue", slsnums)]):
        offset = width * i
        rects = ax.bar(x + offset, vals, width, label=label, color=color)
        #ax.bar_label(rects, padding = 3)

    ax.set(ylabel="Total Transactions")
    ax.set(xlabel="Number of Records")

    ax.set_xticks(x + width) 
    ax.set_xticklabels(keys)

    ax.legend(fontsize=6, loc="upper right")
    ax.set_ylim(ymin=0, ymax=100000)

    fig.set_size_inches(3.6, 2.4)
    fig.tight_layout()
    fig.savefig(Path.cwd() / "pgfs" / "figure4.png")

def fill_config(datadir, name):
    config = dict()

    for dirname in os.listdir(datadir):
        if dirname.split("-")[0] != name:
            continue

        numrecords = int(dirname.split("-")[1])
        datafile = Path.cwd() / datadir / dirname / "0.out"
        config[numrecords] = sqlite_iter(datafile)

    return config


def sqlite_graph(datadir):
    confbase = fill_config(datadir, "baseline")
    confsls = fill_config(datadir, "sls")
    conf = dict()
    keys = sorted(confbase.keys())
    basenums = [ confbase[x] for x in keys ]
    slsnums = [ confsls[x] for x in keys ]

    report_metrics(keys, basenums, slsnums)

if __name__ == "__main__":
    sqlite_graph(Path.cwd() / "tatp")
