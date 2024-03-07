#!/usr/local/bin/python

import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
from pathlib import Path
import csv
import os
import subprocess
import sys

def parse(datafile):
    proc = subprocess.Popen([ "./report-svgparsing.sh", str(datafile) ], stdout=subprocess.PIPE)
    series = []
    while True:
        line = proc.stdout.readline().decode("utf-8").split()
        if not line:
            break
        series.append([line[0], line[1], line[3]])

    return series


def plot(timeseries, name, transaction_size):
    fig, ax = plt.subplots(figsize=(16,10))
    fig.suptitle("Performance counters ({}, Transaction Size {})".format(name, transaction_size))
    fig.patch.set_visible(False)
    ax.axis("off")
    ax.axis("tight")
    tab = ax.table(cellText=timeseries, colLabels=[ "Name", "Samples", "% Counters" ], loc="center", cellLoc="center")

    tab.auto_set_font_size(False)
    tab.set_fontsize(6)
    tab.auto_set_column_width(col=list(range(4))) 
    #fig.tight_layout()
    fig.savefig(Path.cwd() / "report-pmcstat-{}-{:03d}.pdf".format(name, int(transaction_size)))

def timeseries(datadir):
    config = dict()

    for dirname in os.listdir(datadir):
        name = dirname.split("-")[1] 
        transaction_size = dirname.split("-")[2]
        datafile = Path.cwd() / datadir / dirname / "flamegraph.0.svg"
        points = parse(datafile)
        plot(points, name, transaction_size)

    return config

if __name__ == "__main__":
    timeseries(sys.argv[1])
