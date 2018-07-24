#!/usr/bin/env python
'''
This script is for verifying correctness of a run of duplicate marking

'''

import os
import sys
import pysam
import argparse
import logging


def parse_args():
    parser = argparse.ArgumentParser(description="Duplicate Marking Corretness Checker",
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    io_options_group = parser.add_argument_group("Input")
    io_options_group.add_argument("-in", "--input", help="Pre-marking, input bam file")
    io_options_group.add_argument("-correct", "--correct", help="Correctly duplicate marked file")
    io_options_group.add_argument("-check", "--check", help="Duplicate marked file to check")

    console_options_group = parser.add_argument_group("Console Options")
    console_options_group.add_argument('-v', '--verbose', action='store_true', help='verbose output')
    console_options_group.add_argument('--debug', action='store_true', help='Debug Console')

    return parser.parse_args()


def init_logger(args):

    global logger
    if args.debug:
        log_formatter = logging.Formatter('[%(asctime)s][%(levelname)s][%(funcName)s] - %(message)s')
    elif args.verbose:
        log_formatter = logging.Formatter('[%(asctime)s][%(levelname)s][%(funcName)s] - %(message)s')
    else:
        log_formatter = logging.Formatter('[log][%(levelname)s] - %(message)s')

    logger = logging.getLogger(__name__)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(log_formatter)
    logger.addHandler(console_handler)

    if args.debug: level = logging.DEBUG
    elif args.verbose: level = logging.INFO
    else: level = logging.WARNING

    logger.setLevel(level)


def main():
    args = parse_args()
    init_logger(args)
    
    samfile = pysam.AlignmentFile(args.input, 'r')

    duplicates = set()
    for read in samfile.fetch():
        assert (isinstance(read, pysam.AlignedRead))
        if read.is_duplicate:
            duplicates.add(read.rname)


if __name__ == "__main__":
    main()
