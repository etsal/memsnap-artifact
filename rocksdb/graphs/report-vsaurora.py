#!/usr/local/bin/python

import matplotlib
matplotlib.use("pdf")
import matplotlib.pyplot as plt
from pathlib import Path
import rocksgraph
import sys

labels = [ 
            "aurora", 
            "slsdb"
        ]

colors = { 
            "aurora" : "red",
            "slsdb" : "blue",
        }

legends = { 
            "aurora" : "Aurora",
            "slsdb" : "memsnap",
        }

# XXX Needs to be the same order as in rocksgraph.py
metrics = [ "ops", "avg", "p50", "p99" ]

figsize = (8, 8)

sizes = list(reversed(range(15, 21, 1)))

title = "memsnap vs aurora performance"

def rocksdb_graph(ax, confs, colors, legends, sizes, metric, srcpath):
    configs = dict()

    for config in confs:
        configs[config] = rocksgraph.rocksdb_config(srcpath, config, metric, sizes)

    xvals = [ rocksgraph.sizetobytes(size) for size in sizes ]
    for config in configs:
        yvals, yerr = configs[config]
        ax.plot(xvals, yvals, label=config, color=colors[config])
        ax.errorbar(xvals, yvals, yerr=yerr, color=colors[config])

    labels = ["" if i % 4 else val for i, val in enumerate(xvals)]

    ax.set_xticklabels(labels, rotation=45,fontsize=6)
    ax.set_yticklabels(ax.get_yticklabels(), fontsize=6)
    if metric == "ops":
        ax.set(ylabel="Ops/s")
    if metric == "avg" or metric == "p50":
        ax.set(ylabel="Latency (us)")
    if metric == "p99":
        ax.legend([legends[conf] for conf in confs], loc="upper left", fontsize=6)
    ax.set_title(metric)
    ax.set_yticklabels(ax.get_yticks(), rotation=45)


def bgaurora_graph(labels, colors, legends, sizes, srcpath, dstpath, figsize):
    fig, axes = plt.subplots(2, 2, figsize=figsize)
    fig.suptitle(title)

    for i, metric in enumerate(metrics):
        rocksdb_graph(axes[i // 2][i % 2], labels, colors, legends, sizes, metric, srcpath)
    
    fig.tight_layout()
    fig.set_size_inches(*figsize)
    fig.savefig(dstpath)



if __name__ == "__main__":
    srcpath = Path(sys.argv[1])
    dstpath = Path.cwd() / "report-vsaurora.pdf"
    bgaurora_graph(labels, colors, legends, sizes, srcpath, dstpath, figsize)
