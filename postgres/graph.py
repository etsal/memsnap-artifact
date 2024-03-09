import csv
from pathlib import Path
import os
import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
import numpy as np

def y_fmt(y, pos):
    decades = [1e9, 1e6, 1e3, 1e0, 1e-3, 1e-6, 1e-9 ]
    suffix  = ["G", "M", "k", "" , "m" , "u", "n"  ]
    if y == 0:
        return str(0)
    for i, d in enumerate(decades):
        if np.abs(y) >=d:
            val = y/float(d)
            signf = len(str(val).split(".")[1])
            if signf == 0:
                return '{val:d} {suffix}'.format(val=int(val), suffix=suffix[i])
            else:
                if signf == 1:
                    if str(val).split(".")[1] == "0":
                       return '{val:d} {suffix}'.format(val=int(round(val)), suffix=suffix[i]) 
                tx = "{"+"val:.{signf}f".format(signf = signf) +"} {suffix}"
                return tx.format(val=val, suffix=suffix[i])
    return y




def get_data(filename):
    try:
        results = []
        total = 0
        with open(filename) as f:
            reader =  csv.reader(f, delimiter=',')
            for row in reader:
                row = [ float(x) if x != ' ' else -1 for x in row[:-1] ]
                results.append(np.array(row))
                total += 1
        results = np.array(results)
        avg = np.mean(np.array(results), axis=0).tolist()
        std = np.std(results, axis=0).tolist()
        return list(zip(avg, std))
    except Exception as e:
        print("Problem with " + filename + " " + str(e))
        return None

data_values = [ "TPS", "Connection Time", "Latency", "Transaction Per Client", "Failed" ]
ffs = ("ffs", get_data("data/ffs/ffs.csv"))
ffs_m = ("ffs-mmap", get_data("data/ffs-mmap/ffs-mmap.csv"))
ffs_mbd = ("ffs-mmap-bd", get_data("data/ffs-mmap-bufdirect/ffs-mmap-bufdirect.csv"))
sls_sas = ("sls-sas", get_data("data/slsfs-latest/slsfs-latest.csv"))
data = [ ffs, ffs_m, ffs_mbd, sls_sas ] 

groups = [x[0] for x in data ]
data = [x[1] for x in data ]
hatches = [ "//", "/", "||", "*", "+", "-", "++", "--" ]

tps_mean = [ x[0][0] for x in data ]
tps_error = [ x[0][1] for x in data ]

lat_mean = [ x[2][0] for x in data ]
lat_error = [ x[2][1] for x in data ]

total_ckpt_mean = [ x[6][0] for x in data ]
total_ckpt_error = [ x[6][1] for x in data ]

total_sync_mean = [ x[7][0] for x in data ]
total_sync_error = [ x[7][1] for x in data ]

total_write_mean = [ x[8][0] for x in data ]
total_write_error = [ x[8][1] for x in data ]


colors = ["orange", "#d7942e", "#c18529", "blue"]
labels = ["ffs", "ffs+m", "ffs+m,bd", "memsnap"]

fig, ax = plt.subplots()
fig.set_figheight(1.5)
fig.set_figwidth(1.75)
x = np.arange(1)
width = 0.10
space = 0.05
multiplier = 0
data = { labels[i]: k for i, k in enumerate(tps_mean) }
std = { labels[i]: k for i, k in enumerate(tps_error) }
print(data)
for attribute, measurement in data.items():
    offset = (width + space) * multiplier
    print(attribute, measurement, std)
    rects = ax.bar(x + offset, measurement, width, yerr=std[attribute], label=attribute, color=colors[multiplier])
    multiplier += 1

x = np.arange(4)
ax.xaxis.set_tick_params(which='minor', size=0)
ax.tick_params(axis='x', which='both', top=False)
ax.yaxis.set_major_formatter(FuncFormatter(y_fmt))

ax.set_xticks(np.arange(0, 0.55, 0.15))
ax.set_xticklabels(labels, rotation=-90)
ax.set_ylabel("Txn/s")
ax.set_ylim(0, 4500)
fig.tight_layout()
fig.savefig("tps.pgf")
fig.savefig("tps.png")

fig, ax = plt.subplots()
fig.set_figheight(1.5)
fig.set_figwidth(1.75)
x = np.arange(1)
multiplier = 0
data = { labels[i]: k for i, k in enumerate(lat_mean) }
std = { labels[i]: k for i, k in enumerate(lat_error) }
for attribute, measurement in data.items():
    offset = (width + space) * multiplier
    print(attribute, measurement)
    rects = ax.bar(x + offset, measurement, width, yerr=std[attribute], label=attribute, color=colors[multiplier])
    multiplier += 1

ax.xaxis.set_tick_params(which='minor', size=0)
ax.tick_params(axis='x', which='both', top=False)
ax.yaxis.set_major_formatter(FuncFormatter(y_fmt))

ax.set_ylabel("Latency (ms)")
ax.set_xticks(np.arange(0, 0.55, 0.15))
ax.set_xticklabels(labels, rotation=-90)
ax.set_ylim(0, 10)
fig.tight_layout()
fig.savefig("lat.pgf")
fig.savefig("lat.png")

fig, ax = plt.subplots()
ax.bar(groups, total_ckpt_mean, yerr=total_ckpt_error, edgecolor="black", color="white", hatch=hatches[0:len(data)])
ax.set_ylabel("Total Time Checkpoint (s)")
ax.set_xticklabels(groups, rotation=-45)
fig.savefig("ckpt.pgf")
fig.savefig("ckpt.png")

fig, ax = plt.subplots()
ax.bar(groups, total_write_mean, yerr=total_write_error, edgecolor="black", color="white", hatch=hatches[0:len(data)])
ax.set_ylabel("Total Write Time (s)")
ax.set_xticklabels(groups, rotation=-45)
fig.savefig("write.pgf")
fig.savefig("write.png")

fig, ax = plt.subplots()
ax.bar(groups, total_sync_mean, yerr=total_sync_error, edgecolor="black", color="white", hatch=hatches[0:len(data)])
ax.set_ylabel("Total Sync Time (s)")
ax.set_xticklabels(groups, rotation=-45)
fig.savefig("sync.pgf")
fig.savefig("sync.png")
