#!/usr/bin/python3

import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
from pathlib import Path
import os
from statistics import stdev

def getint(line, index):
    return int(line.strip().split()[index])

def getfloat(line, index):
    return float(line.strip().split()[index])

def get_sysctl(valuefile, sysctlkey):
    with open(valuefile) as f:
        for line in f.readlines():
            sysctl, value = line.split(":")
            if sysctl.split(".")[1] != sysctlkey:
                continue
            return int(value.strip())

        print("WARNING: KEY {} NOT FOUND IN {}, USING 0".format(sysctl, subdir))
        return 0
    

def appckpt_subdir(subdir, sysctl):
    files = os.listdir(subdir)
    data = [ get_sysctl(subdir / file, sysctl) for file in files if file.split(".")[0] == "sysctl"]
    data = [ d for d in data if d != [] ]

    if len(data) == 0:
        print("WARNING: NO DATA POINTS FOR {}, USING (0, 0)".format(subdir))
        return (0, 0)

    if len(data) == 1:
        return (sum(data), 0)

    return (sum(data) / len(data), stdev(data))

def appckpt_config(basedir, sysctl, sizes):
    subdirs = reversed(sorted([ d for d in list(os.listdir(basedir)) if d.split("-")[1] == "aurora"]))
    subdirs = [ d for d in subdirs if int(d.split("-")[2]) in sizes ]
    results = [ appckpt_subdir(basedir / subdir, sysctl) for subdir in subdirs]
    yval = [ result[0] for result in results ]
    yerr = [ result[1] for result in results ]
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

def appckpt_graph(title, axlabels, sysctl, sizes, srcpath, dstpath):
    yvals, yerr = appckpt_config(srcpath, sysctl, sizes)

    fig, ax = plt.subplots(1, 1, figsize=(8, 8))
    #fig.suptitle(title, fontsize=8)

    xvals = [ sizetobytes(size) for size in sizes ]
    ax.plot(xvals, yvals)
    ax.errorbar(xvals, yvals, yerr=yerr)

    ax.set_xticks(xvals)
    ax.set_xticklabels(xvals, rotation=45,fontsize=6)
    ax.set(ylabel=axlabels["ylabel"])
    ax.set(xlabel=axlabels["xlabel"])

    fig.tight_layout()
    fig.set_size_inches(8, 8)
    fig.savefig(dstpath)
