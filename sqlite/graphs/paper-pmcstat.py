#!/usr/local/bin/python

import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
from pathlib import Path
import csv
import os
import subprocess
import sys

base_syscalls = [ "0x22000", "kern_fsync", "sys_write", "sys_read" ]
sls_syscalls = [ "0x22000", "slsckpt_dataregion", "slsckpt_dataregion_dump", "vm_fault" ]

descriptions = {
    "sys_write" : "write",
    "sys_read" : "read",
    "kern_fsync" : "fsync",
    "0x22000" : "userspace",
    "vm_fault" : "page faults",
    "slsckpt_dataregion_dump" : "memsnap flush",
    "slsckpt_dataregion" : "memsnap",
}

configs = {
    "baseline" : base_syscalls,
    "sls" : sls_syscalls,
}

def parse(datafile, syscalls):
    proc = subprocess.Popen([ "./paper-svgparsing.sh", str(datafile) ], stdout=subprocess.PIPE)
    data = dict()
    while True:
        line = proc.stdout.readline().decode("utf-8").split()
        if not line:
            break
        if line[0] not in syscalls:
            continue
        data[line[0]] = line[3].strip('%')
    return data

def parseconfig(config):
    datafile = Path.cwd() / bench / "-".join([ config, "batch", "8", bench ]) / "flamegraph.0.svg"
    return parse(datafile, configs[config])

def baseline(descr, value):
    print(r"{} & {}\% ".format(descr, value), end="")

def slsline(descr, value):
    print(r"& {} & {}\% \\".format(descr, value))

def pmcstat(bench):
    data = dict()
    slspoints = parseconfig("sls")
    basepoints = parseconfig("baseline")

    for (basename, slsname) in zip(base_syscalls, sls_syscalls):
        baseline(descriptions[basename], basepoints[basename])
        slsline(descriptions[slsname], slspoints[slsname])

def header():
    print(r"\begin{tabular}{@{} l r l r @{}}")
    print(r"\toprule")
    print(r"{\bf Baseline} &{\bf \%CPU} &{\bf \NAME}  &{\bf \%CPU}\\")
    print(r"\midrule")


def footer():
    print(r"\bottomrule")
    print(r"\end{tabular}")


if __name__ == "__main__":
    header()
    for bench in [ "fillrandbatch", "fillseqbatch" ]:
        print(r"{\bf Random IO} \\ " if bench == "fillrandbatch" else r"\bf{Sequential IO} \\ ")
        pmcstat(bench)
        print(r"\midrule")
    footer()
