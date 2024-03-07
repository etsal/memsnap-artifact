#!/usr/local/bin/python

import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
from pathlib import Path
import csv
import os
import sys

counters = {
        "user" : ("User time", "Seconds"),
        "system" : ("System time", "Seconds"),
        "voluntary" : ("Voluntary context switches", "Context Switches"),
        "involuntary" : ("Involuntary context switches", "Context Switches"),
    }

def plot(ax, timeseries, counter, name, transaction_size):
    (title, ytitle) = counters[counter]
    for tick in ax.get_xticklabels():
        tick.set_rotation(45)

    ax.title.set_text(title)
    ax.set(ylabel=ytitle)
    ax.set(xlabel="Seconds")
    xvals = [ i + 1 for i in range(len(timeseries)) ]
    ax.plot([0] + xvals, [0] + timeseries) 
    ax.set_ylim(ymin=0)

def allplots(timeseries, name, transaction_size):
    fig, ax = plt.subplots(2, 2, figsize=(8, 8))
    fig.suptitle("Rusage statistics ({}, transaction size {})".format(name, transaction_size))

    for i, counter in enumerate(counters.keys()):
        plot(ax[i // 2, i % 2], timeseries[counter], counter, name, transaction_size)

    fig.set_size_inches(7.2, 6)
    fig.tight_layout()
    fig.savefig(Path.cwd() / "report-rusage-{}-{:03d}.pdf".format(name, int(transaction_size)))

def timestamptoseconds(timestamp):
    time, millis = timestamp.split(".")
    hours, minutes, seconds = list(map(int, time.split(":")))

    total = ((((((hours * 60) + minutes) * 60) + seconds) * 1000) + (int(millis) / 1000)) / 1000

    return total

def parse(datafile, stat):
    series = []
    with open(datafile, "r") as f:
        for line in f.readlines():
            line = line.split()
            if not stat in line:
                continue
            if stat in ["user", "system"]:
                seconds = timestamptoseconds(line[-1])
                series.append(seconds)
            else:
                series.append(int(line[-1]))

    return series

def timeseries(datadir):
    for dirname in os.listdir(datadir):
        name = dirname.split("-")[1] 
        transaction_size = dirname.split("-")[2]
        datafile = Path.cwd() / datadir / dirname / "rusage.0"
        timeseries = dict()
        for counter in counters.keys():
            timeseries[counter] = parse(datafile, counter)
        allplots(timeseries, name, transaction_size)

if __name__ == "__main__":
    timeseries(sys.argv[1])
