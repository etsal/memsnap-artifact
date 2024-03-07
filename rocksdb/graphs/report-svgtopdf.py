#!/usr/local/bin/python

from pathlib import Path
import os
import subprocess
import sys

def svgtopdf(datadir):
    config = dict()

    for dirname in os.listdir(datadir):
        name = dirname.split("-")
        pdfname = "-".join(["report", "flamegraph", name[1], name[2]])
        svgfile = Path.cwd() / datadir / dirname / "flamegraph.0.svg"
        pdffile = Path.cwd() / "{}.pdf".format(pdfname)
        with open(pdffile, "w") as out:
            subprocess.run(["rsvg-convert", "-f", "pdf", str(svgfile)], stdout=out)

if __name__ == "__main__":
    svgtopdf(sys.argv[1])
