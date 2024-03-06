#!/usr/local/bin/python

from pathlib import Path
import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
import os
import random
from statistics import stdev
import sys

prelude=r"""
\documentclass{article}
\usepackage{booktabs}
\usepackage{graphicx}

\newcommand{\code}[1]{\texttt{\detokenize{#1}}}
\begin{document}
\begin{table*}[!tb]
\resizebox{\columnwidth}{!}{
"""

epilogue=r"""
}
\end{table*}

\end{document}
"""

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
    config = dict()

    for dirname in os.listdir(datadir):
        name = dirname.split("-")

        transaction_size = int(name[2])
        if transaction_size in config:
            continue
        config[int(transaction_size)] = dict()
        conf = config[int(transaction_size)] 

        counts = dict()
        times = dict()

        slsname = "-".join([ "sls" ] + name[1:])
        basename = "-".join([ "baseline" ] + name[1:])

        slsfile = Path.cwd() / datadir / slsname / "dtrace.0"
        basefile = Path.cwd() / datadir / basename / "dtrace.0"
        dtrace_iter(slsfile, times, counts)
        dtrace_iter(basefile, times, counts)

        for key in times:
            conf[key] = (times[key], counts[key])

    return config


def tonum(value):
    return round(float(value) / 1000, 1)

def line(data):
    ops = ["memsnap", "fsync", "write", "read"]
    for (time, count) in [ map(lambda x: tonum(x), data[op]) for op in ops ]:
        print(r"& {}~us & {}~K ".format(time, count), end="")
    print(r"\\")

def dtrace(bench):
    data = fill_config(bench)
    for transaction_size in sorted(list(map(int, data.keys())))[::4]:
        print(r" {} KiB".format((transaction_size) * 4), end="")
        line(data[transaction_size])

def header():
    print(prelude)
    print(r"\begin{tabular}{@{} c | c c | *{6}{c} @{}}")
    print(r"\toprule")
    print(r"& \multicolumn{2}{c}{{\bf \code{memsnap}}} & \multicolumn{2}{c}{{\bf \code{fsync}}} & \multicolumn{2}{c}{{\bf \code{write}}} & \multicolumn{2}{c}{{\bf \code{read}}} \\")
    print(r"{\bf Transaction Size} ", end="")
    for _ in range(4):
        print(r"& Latency & Total Ops", end="")
    print(r"\\")
    print(r"\midrule")


def footer():
    print(r"\bottomrule")
    print(r"\end{tabular}")
    print(epilogue)


def sqlite_graph(datadir):
    conf = fill_config(datadir)
    #report_dtrace(conf)

if __name__ == "__main__":
    header()
    for bench in [ "fillrandbatch", "fillseqbatch" ]:
        print(r"{\bf Random IO} \\ " if bench == "fillrandbatch" else r"{\bf Sequential IO} \\ ")
        dtrace(bench)
        print(r"\midrule")
    footer()

