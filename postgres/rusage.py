import csv
from pathlib import Path
import os
import re
import pprint
import matplotlib
from datetime import datetime, timedelta
from matplotlib.ticker import FuncFormatter
matplotlib.use('Agg')

import matplotlib.pyplot as plt
import numpy as np

def convert(date):
    return timedelta(hours=date.hour, minutes=date.minute, seconds=date.second, microseconds=date.microsecond)

def process_worker_data(data):
    final = {}
    for l in data:
        try:
            l = l.split("postgres")[1]
        except Exception as e:
            continue
        if "user time" in l:
            final["user time"] = convert(datetime.strptime(l.split()[-1], "%H:%M:%S.%f"))
        if "system time" in l:
            final["system time"] = convert(datetime.strptime(l.split()[-1], "%H:%M:%S.%f"))
        if "page reclaims" in l:
            final["page reclaims"] = int(l.split()[-1])
        if "maximum RSS" in l:
            final["maximum RSS"] = float(l.split()[-2])
        if "integral unshared data" in l:
            final["integral unshared data"] = float(l.split()[-2])
        if "integral unshared stack" in l:
            final["integral unshared stack"] = float(l.split()[-2])
        if " voluntary context switches" in l:
            final["voluntary context switches"] = int(l.split()[-1])
        if " involuntary context switches" in l:
            final["involuntary context switches"] = int(l.split()[-1])
        if "page faults" in l:
            final["page faults"] = int(l.split()[-1])
        if "swaps" in l:
            final["swaps"] = int(l.split()[-1])
        if "block reads" in l:
            final["block reads"] = int(l.split()[-1])
        if "block writes" in l:
            final["block writes"] = int(l.split()[-1])


    return final

def process_data(data):
    rusage_data, ps_data = data.split("=== PS ===")
    header = ps_data.split("\n")[0].split()
    index = 0
    for i, h in enumerate(header):
        if (h == pid):
            index = i
            break

    ps_data = ps_data.split("\n")
    worker_processes = []

    for line in ps_data:
        if "postgres:" in line:
            line = line.split()
            worker_processes.append(line[index])


    rusage_data = rusage_data.split("\n")
    workers = []
    for worker in worker_processes:
        worker_data = [ f for f in rusage_data if f.strip().startswith(worker) ]
        workers.append((process_worker_data(worker_data)).copy())
    avgs = {}
    for k in workers[0].keys():
        if k == "user time" or k == "system time":
            avgs[k] = (sum([d[k] for d in workers], timedelta()) / len(workers)).total_seconds()
        else:
            avgs[k] = float(sum(d[k] for d in workers) / len(workers))

    return avgs

def process_gstat(data):
    # Cut header and 0,0,0, line
    data = data.split('\n')[2:]
    count = 0
    kibs = 0
    iops = 0
    for l in data:
        if (len(l) == 0):
            continue

        l = l.split(',')
        kibs += float(l[8])
        iops += float(l[3])
        count += 1;

    return {
            "kibs": kibs / count,
            "iops": iops / count
    }

data_dirs = [ "ffs", "ffs-mmap", "ffs-mmap-bufdirect", "slsfs-latest"]

final = {}

for d in data_dirs:
    path = Path("data/{}".format(d))
    # Dirty just get all the files
    reg = re.compile("rusage([0-9]+)t.log")
    ruse = [ f for f in os.listdir(path) if reg.match(f) ][0]

    reg = re.compile("rusage([0-9]+)t-before.log")
    before = [ f for f in os.listdir(path) if reg.match(f) ][0]
    reg = re.compile("rusage([0-9]+)t-after.log")
    after = [ f for f in os.listdir(path) if reg.match(f) ][0]

    final[d] = {}
    p = path / ruse
    threads = re.search(r"([0-9]+)", ruse).group(0)
    with open(p) as f:
        mydata = process_data(f.read())

    p = path / before
    with open(p) as f:
        before = process_data(f.read())

    p = path /after 
    with open(p) as f:
        after = process_data(f.read())

    p = path / "gstat.out"
    with open(p) as f:
        gstat = process_gstat(f.read());

    diff = { k : after[k] - before[k] for k in after.keys() }
    final[d][threads] = (mydata, diff, gstat)


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

#interested_keys = [ ("user time", "User Time", 0), ("system time", "System Time", 0), ("page reclaims", "Page Reclaims", 1),  ("block reads", "Reads", 1),
#                   ("block writes", "Writes", 1), ("involuntary context switches", "Invol. CS", 1), ("voluntary context switches", "Vol. CS", 1), ("page faults", "Page Faults", 1),
#                   ("kibs", "KiB/s", 2), ("iops", "IOP/s", 2)]

interested_keys = [ ("kibs", "KiB/s", 2, (0, 600000)), ("iops", "IOP/s", 2, (0, 15000)) ]
for key in interested_keys:
    print(key)
    data_key = key[0]
    data_label = key[1]
    data_from = key[2]
    ylim = key[3]
    fig, ax = plt.subplots()
    fig.set_figheight(1.5)
    fig.set_figwidth(1.75)
    threads=sorted(list(int(d) for d in final["ffs"].keys()))
    data = {}
    for fs, dic in final.items():
        d = []
        for t in threads:
            d.append(dic[str(t)][data_from][data_key])
        data[fs] = d

    x = np.arange(len(final["ffs"].keys()))
    width = 0.10
    space = 0.05
    multiplier = 0

    colors = ["orange", "#d7942e", "#c18529", "blue"]
    labels = ["ffs", "ffs+m", "ffs+m,bd", "memsnap"]

    for attribute, measurement in data.items():
        offset = (width + space) * multiplier
        rects = ax.bar(x + offset, measurement, width, label=attribute, color=colors[multiplier])
        #ax.bar_label(rects, padding = 3)
        multiplier += 1
    
    ax.xaxis.set_tick_params(which='minor', size=0)
    ax.tick_params(axis='x', which='both', top=False)
    ax.yaxis.set_major_formatter(FuncFormatter(y_fmt))
    ax.set_ylim(ylim)
    ax.set_ylabel(data_label)
    ax.set_xticks(np.arange(0, 0.55, 0.15))
    ax.set_xticklabels(labels, rotation=-90)
    data_key = data_key.replace(" ", "_")
    fig.tight_layout()

    fig.savefig(f"{data_key}.png")
