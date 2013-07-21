#!/usr/bin/env python
"""
    Print a list of movies in the current directory w/o .bif files

    Copyright 2013 by Brian C. Lane <bcl@brianlane.com>
    All Rights Reserved
"""
import os
from glob import glob

def main():
    """
    Main code goes here
    """
    for f in glob("*.m??"):
        bif = os.path.splitext(f)[0] + "-SD.bif"
        if not os.path.exists(bif):
            print("%s is missing" % bif)

if __name__ == '__main__':
    main()

