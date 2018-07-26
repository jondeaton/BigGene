#!/usr/bin/env python
'''
This script is for verifying correctness of a run of duplicate marking
'''


import os
import sys
import pysam
import argparse
import logging


def get_duplicates(bam_file):
    """
    Finds all of the duplicate reads within a given BAM file.
    :param bam_file: The BAM file to get the duplicate reads from
    :return: A set containing all duplicate reads from within the BAM file
    """
    samfile = pysam.AlignmentFile(bam_file, 'r')

    duplicates = set()
    total_reads = 0
    for read in samfile.fetch(until_eof=True):
        assert (isinstance(read, pysam.AlignedSegment))
        total_reads += 1
        if read.is_duplicate:
            duplicates.add(read)
    logger.debug("total reads: %d" % total_reads)
    return duplicates


def duplicate_stats(duplicates):

    logger.info("Total duplicates: %d" % len(duplicates))

    primary = 0
    secondary = 0
    unmapped = 0
    read1 = 0
    read2 = 0

    for read in duplicates:
        assert (isinstance(read, pysam.AlignedSegment))

        if read.is_secondary:
            secondary += 1
        else:
            primary += 1

        if read.is_unmapped:
            unmapped += 1

        if read.is_read1:
            read1 += 1

        if read.is_read2:
            read2 += 1

    logger.info("primary: %d" % primary)
    logger.info("secondary: %d" % secondary)
    logger.info("unmapped: %d" % unmapped)
    logger.info("read1: %d" % read1)
    logger.info("read2: %d" % read2)

def main():
    args = parse_args()
    init_logger(args)

    logger.info("Getting duplicates for: %s" % os.path.basename(args.correct))
    correct_duplicates = get_duplicates(args.correct)
    duplicate_stats(correct_duplicates)

    logger.info("Getting duplicates for: %s" % os.path.basename(args.check))
    check_duplicates = get_duplicates(args.check)
    duplicate_stats(check_duplicates)

    mutual = check_duplicates.intersection(correct_duplicates)
    false_positives = check_duplicates - correct_duplicates
    missed_dups = correct_duplicates - check_duplicates

    logger.info("MUTUAL:")
    duplicate_stats(mutual)

    logger.info("FALSE POSITIVES:")
    duplicate_stats(false_positives)

    logger.info("MISSED:")
    duplicate_stats(missed_dups)

    # logger.info("Getting duplicates for: %s" % args.input)
    # original_duplicates = get_duplicates(args.input)
    # logger.info("Original duplicates: %d" % len(original_duplicates))


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


if __name__ == "__main__":
    main()
