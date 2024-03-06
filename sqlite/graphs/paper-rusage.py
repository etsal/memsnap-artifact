#!/usr/local/bin/python

import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
from pathlib import Path
import csv
import os
import re
import subprocess
import sys

counters = {
        "user" : "User time",
        "system" : "System time",
        "voluntary" : "Voluntary context switches",
        "involuntary" : "Involuntary context switches",
        "context" : "Involuntary context switch \%",
    }

def timestamptoseconds(timestamp):
    time, millis = timestamp.split(".")
    hours, minutes, seconds = list(map(int, time.split(":")))

    # Way too many digits in the input, get the first three
    millis = int(str(millis)[:3])

    total = round((((hours * 60) + minutes) * 60) + seconds + ((millis) / 1000), 1)
    return total

def parse(datafile, stat):
    val = None
    with open(datafile, "r") as f:
        for line in f.readlines():
            line = line.split()
            if not stat in line:
                continue
            if stat in ["user", "system"]:
                val = timestamptoseconds(line[-1])
            else:
                val = int(line[-1])

    return val

def stats(bench, config):
    datafile = Path.cwd() / bench / "-".join([ config, "batch", "8", bench ]) / "rusage.0"
    vals = dict()
    for counter in counters.keys():
        vals[counter] = parse(datafile, counter)
    return vals

def basesecs(descr, value):
    print(r"{} & {}s ".format(descr, value), end="")

def slssecs(value):
    print(r"& {}s \\".format(value))

def basepercent(descr, value):
    print(r"{} & {}\% ".format(descr, value), end="")

def slspercent(value):
    print(r"& {}\% \\".format(value))

def percent(nom, denom):
    return round((float(nom) / (nom + denom)) * 100, 1)

def rusage(bench):
    data = dict()

    slspoints = stats(bench, "sls")
    slspoints["context"] = percent(slspoints["involuntary"], slspoints["voluntary"])
    basepoints = stats(bench, "baseline")
    basepoints["context"] = percent(basepoints["involuntary"], basepoints["voluntary"])

    basesecs(counters["user"], basepoints["user"])
    slssecs(slspoints["user"])

    basesecs(counters["system"], basepoints["system"])
    slssecs(slspoints["system"])
    
    basepercent(counters["context"], basepoints["context"])
    slspercent(slspoints["context"])


def header():
    print(r"\begin{tabular}{@{} l r r @{}}")
    print(r"\toprule")
    print(r"& {\bf Baseline} &{\bf \NAME} \\")
    print(r"\midrule \\")


def footer():
    print(r"\bottomrule")
    print(r"\end{tabular}")

if __name__ == "__main__":

    header()
    for bench in [ "fillrandbatch", "fillseqbatch" ]:
        print(r"{\bf Random IO} \\ " if bench == "fillrandbatch" else r"\bf{Sequential IO} \\ ")
        rusage(bench)
        print(r"\midrule")
    footer()
