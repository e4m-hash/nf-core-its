#!/usr/bin/env python3
"""
Parse multiple Cutadapt log files and generate a unified summary CSV.

Handles nf-core/cutadapt module output format.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import logging
import re
import sys
from pathlib import Path
from statistics import mean, stdev
from typing import Any, Dict, List, TextIO


def open_text(path: Path) -> TextIO:
    """Open text file, handling gzip compression automatically."""
    if path.suffix == ".gz":
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return path.open("rt", encoding="utf-8", errors="replace")


def extract_sample_id(log_path: Path) -> str:
    """
    Extract sample ID from log filename.

    Examples:
        B1.cutadapt.log -> B1
        sample123.log -> sample123
    """
    name = log_path.name
    # Remove common suffixes
    for suffix in [".cutadapt.log", ".log", ".txt"]:
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return log_path.stem


def parse_single_cutadapt_log(log_path: Path) -> Dict[str, Any]:
    """
    Parse a single Cutadapt log file.

    Returns a dictionary with sample statistics.
    """
    sample_id = extract_sample_id(log_path)
    total_reads = None
    passing_filters_pct = None
    total_written_pct = None
    read1_adapter = None
    read2_adapter = None

    with open_text(log_path) as f:
        for line in f:
            stripped = line.strip()

            # Total read pairs processed
            if stripped.startswith("Total read pairs processed:"):
                match = re.search(r":\s*([\d,]+)", stripped)
                if match:
                    total_reads = int(match.group(1).replace(",", ""))
                    logging.debug("Found total_reads: %d", total_reads)

            # Total reads processed (single-end)
            elif stripped.startswith("Total reads processed:"):
                match = re.search(r":\s*([\d,]+)", stripped)
                if match:
                    total_reads = int(match.group(1).replace(",", ""))
                    logging.debug("Found total_reads (SE): %d", total_reads)

            # Read 1 with adapter
            elif stripped.startswith("Read 1 with adapter:"):
                match = re.search(r"\((\d+(?:\.\d+)?)%\)", stripped)
                if match:
                    read1_adapter = float(match.group(1))
                    logging.debug("Found read1_adapter: %.2f%%", read1_adapter)

            # Read 2 with adapter
            elif stripped.startswith("Read 2 with adapter:"):
                match = re.search(r"\((\d+(?:\.\d+)?)%\)", stripped)
                if match:
                    read2_adapter = float(match.group(1))
                    logging.debug("Found read2_adapter: %.2f%%", read2_adapter)

            # Pairs written (passing filters) - paired-end
            elif stripped.startswith("Pairs written (passing filters):"):
                match = re.search(r"\((\d+(?:\.\d+)?)%\)", stripped)
                if match:
                    passing_filters_pct = float(match.group(1))
                    logging.debug("Found passing_filters: %.2f%%", passing_filters_pct)

            # Reads written (passing filters) - single-end
            elif stripped.startswith("Reads written (passing filters):"):
                match = re.search(r"\((\d+(?:\.\d+)?)%\)", stripped)
                if match:
                    passing_filters_pct = float(match.group(1))
                    logging.debug(
                        "Found passing_filters (SE): %.2f%%", passing_filters_pct
                    )

            # Total written (filtered) - look for percentage in parentheses
            elif stripped.startswith("Total written (filtered):"):
                match = re.search(r"\((\d+(?:\.\d+)?)%\)", stripped)
                if match:
                    total_written_pct = float(match.group(1))
                    logging.debug("Found total_written: %.2f%%", total_written_pct)

    return {
        "sample_id": sample_id,
        "source_file": log_path.name,
        "total_reads": total_reads,
        "read1_adapter_pct": read1_adapter,
        "read2_adapter_pct": read2_adapter,
        "passing_filters_pct": passing_filters_pct,
        "total_written_pct": total_written_pct,
    }


def parse_all_logs(log_paths: List[Path]) -> List[Dict[str, Any]]:
    """Parse multiple Cutadapt log files and combine results."""
    all_rows = []

    for log_path in log_paths:
        if not log_path.exists():
            logging.warning("Log file not found, skipping: %s", log_path)
            continue

        try:
            row = parse_single_cutadapt_log(log_path)

            # Only add if we got some data
            if row["total_reads"] is not None:
                all_rows.append(row)
                logging.info(
                    "Parsed sample '%s' from %s (reads: %s, passing: %s%%)",
                    row["sample_id"],
                    log_path.name,
                    row["total_reads"],
                    row["passing_filters_pct"],
                )
            else:
                logging.warning("No valid data found in %s", log_path.name)

        except Exception as e:
            logging.error("Failed to parse %s: %s", log_path, e, exc_info=True)
            continue

    return all_rows


def calculate_statistics(
    rows: List[Dict[str, Any]],
) -> tuple[Dict[str, Any], Dict[str, Any]]:
    """Calculate mean and standard deviation for numeric columns."""
    if not rows:
        return {}, {}

    numeric_cols = [
        "total_reads",
        "read1_adapter_pct",
        "read2_adapter_pct",
        "passing_filters_pct",
        "total_written_pct",
    ]

    mean_row = {"sample_id": "mean", "source_file": ""}
    std_row = {"sample_id": "std", "source_file": ""}

    for col in numeric_cols:
        values = [r[col] for r in rows if r.get(col) is not None]
        if values:
            mean_row[col] = mean(values)
            std_row[col] = stdev(values) if len(values) > 1 else 0.0
        else:
            mean_row[col] = None
            std_row[col] = None

    return mean_row, std_row


def write_csv(
    rows: List[Dict[str, Any]],
    output_path: Path,
    with_stats: bool = True,
    include_source: bool = False,
) -> None:
    """Write results to CSV file with optional summary statistics."""
    fieldnames = [
        "sample_id",
        "total_reads",
        "read1_adapter_pct",
        "read2_adapter_pct",
        "passing_filters_pct",
        "total_written_pct",
    ]

    if include_source:
        fieldnames.insert(1, "source_file")

    if not rows:
        logging.warning("No data to write, creating empty CSV")
        with output_path.open("wt", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
        return

    with output_path.open("wt", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

        if with_stats and len(rows) > 0:
            mean_row, std_row = calculate_statistics(rows)
            writer.writerow(mean_row)
            writer.writerow(std_row)

    logging.info("Written %d samples to %s", len(rows), output_path)


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Parse multiple Cutadapt log files and generate unified summary CSV.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Single log file
  DetectPrimer.py cutadapt.log --out summary.csv

  # Multiple log files (collected by Nextflow)
  DetectPrimer.py *.cutadapt.log --out summary.csv

  # With debug output
  DetectPrimer.py *.log --out summary.csv --log-level DEBUG

  # Include source filenames
  DetectPrimer.py *.log --out summary.csv --include-source
        """,
    )
    parser.add_argument(
        "log_files",
        nargs="+",
        type=Path,
        help="Input Cutadapt log file(s). Can specify multiple files.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("cutadapt_summary.csv"),
        help="Output CSV file path (default: cutadapt_summary.csv).",
    )
    parser.add_argument(
        "--no-stats",
        action="store_true",
        help="Do not append mean/std rows to output.",
    )
    parser.add_argument(
        "--include-source",
        action="store_true",
        help="Include source log filename in output.",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["ERROR", "WARNING", "INFO", "DEBUG"],
        help="Logging verbosity (stderr).",
    )
    return parser.parse_args()


def main() -> int:
    """Main entry point."""
    args = parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(levelname)s: %(message)s",
        stream=sys.stderr,
    )

    if not args.log_files:
        logging.error("No input log files specified")
        return 1

    logging.info("Processing %d log file(s)", len(args.log_files))

    try:
        # Parse all log files
        all_rows = parse_all_logs(args.log_files)

        if not all_rows:
            logging.error("No valid sample data found in any log file")
            logging.error("Please check log file format with --log-level DEBUG")
            # Still create empty CSV with headers
            write_csv([], args.out, with_stats=False)
            return 1

        # Write unified CSV
        write_csv(
            all_rows,
            args.out,
            with_stats=not args.no_stats,
            include_source=args.include_source,
        )

        logging.info("Successfully processed %d log files", len(args.log_files))
        logging.info("Total samples found: %d", len(all_rows))

        return 0

    except Exception as e:
        logging.exception("Failed to process log files: %s", e)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
