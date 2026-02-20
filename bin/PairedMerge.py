#!/usr/bin/env python3

import sys
import os
import re
import csv
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="Parse VSEARCH log files to CSV.")
    parser.add_argument("log_files", nargs="+", help="List of VSEARCH log files.")
    parser.add_argument(
        "--output",
        "-o",
        default="vsearch_merge_summary.csv",
        help="Output CSV filename.",
    )
    return parser.parse_args()


def parse_single_log(log_path):
    filename = os.path.basename(log_path)
    # 확장자 제거 후 샘플명 추출
    sample_name = os.path.splitext(filename)[0]

    # 데이터 저장용 딕셔너리 초기화 (기본값 빈 문자열)
    stats = {
        "Sample": sample_name,
        "Total_Pairs": "",
        "Merged_Count": "",
        "Merged_Percent": "",
        "Not_Merged_Count": "",
        "Not_Merged_Percent": "",
        "Mean_Read_Length": "",
        "Mean_Fragment_Length": "",
        "Std_Dev_Fragment_Length": "",
        "Mean_Expected_Error_Merged": "",
        "Elapsed_Time": "",
        "Max_Memory": "",
    }

    # 정규표현식 정의 (strip()된 라인 기준)
    # 예: "105199  Pairs" -> 숫자 시작
    patterns = {
        "pairs": re.compile(r"^(\d+)\s+Pairs"),
        "merged": re.compile(r"^(\d+)\s+Merged\s+\(([\d\.]+)%\)"),
        "not_merged": re.compile(r"^(\d+)\s+Not merged\s+\(([\d\.]+)%\)"),
        "mean_read_len": re.compile(r"^([\d\.]+)\s+Mean read length"),
        "mean_frag_len": re.compile(r"^([\d\.]+)\s+Mean fragment length"),
        "std_dev_frag": re.compile(
            r"^([\d\.]+)\s+Standard deviation of fragment length"
        ),
        "mean_exp_err": re.compile(
            r"^([\d\.]+)\s+Mean expected error in merged sequences"
        ),
        "elapsed": re.compile(r"^Elapsed time\s+(.+)"),
        "memory": re.compile(r"^Max memory\s+(.+)"),
    }

    try:
        with open(log_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                # 각 패턴 매칭 확인
                # 1. Pairs
                m = patterns["pairs"].search(line)
                if m:
                    stats["Total_Pairs"] = m.group(1)
                    continue

                # 2. Merged
                m = patterns["merged"].search(line)
                if m:
                    stats["Merged_Count"] = m.group(1)
                    stats["Merged_Percent"] = m.group(2)
                    continue

                # 3. Not Merged
                m = patterns["not_merged"].search(line)
                if m:
                    stats["Not_Merged_Count"] = m.group(1)
                    stats["Not_Merged_Percent"] = m.group(2)
                    continue

                # 4. Statistics
                if "Mean read length" in line:
                    m = patterns["mean_read_len"].search(line)
                    if m:
                        stats["Mean_Read_Length"] = m.group(1)

                elif "Mean fragment length" in line:
                    m = patterns["mean_frag_len"].search(line)
                    if m:
                        stats["Mean_Fragment_Length"] = m.group(1)

                elif "Standard deviation of fragment length" in line:
                    m = patterns["std_dev_frag"].search(line)
                    if m:
                        stats["Std_Dev_Fragment_Length"] = m.group(1)

                elif "Mean expected error in merged sequences" in line:
                    m = patterns["mean_exp_err"].search(line)
                    if m:
                        stats["Mean_Expected_Error_Merged"] = m.group(1)

                # 5. Performance
                elif line.startswith("Elapsed time"):
                    m = patterns["elapsed"].search(line)
                    if m:
                        stats["Elapsed_Time"] = m.group(1)

                elif line.startswith("Max memory"):
                    m = patterns["memory"].search(line)
                    if m:
                        stats["Max_Memory"] = m.group(1)

    except Exception as e:
        print(f"Error processing {log_path}: {e}", file=sys.stderr)
        return None

    return stats


def main():
    args = parse_args()

    collected_stats = []

    # 파일 순회
    for log_file in args.log_files:
        if not os.path.exists(log_file):
            print(f"Warning: File not found: {log_file}", file=sys.stderr)
            continue

        stats = parse_single_log(log_file)
        if stats:
            collected_stats.append(stats)

    if not collected_stats:
        print("No valid data found.", file=sys.stderr)
        sys.exit(1)

    # CSV 헤더 정의
    headers = [
        "Sample",
        "Total_Pairs",
        "Merged_Count",
        "Merged_Percent",
        "Not_Merged_Count",
        "Not_Merged_Percent",
        "Mean_Read_Length",
        "Mean_Fragment_Length",
        "Std_Dev_Fragment_Length",
        "Mean_Expected_Error_Merged",
        "Elapsed_Time",
        "Max_Memory",
    ]

    # CSV 쓰기
    try:
        with open(args.output, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=headers)
            writer.writeheader()
            for row in collected_stats:
                writer.writerow(row)
        print(f"Summary written to {args.output}")
    except IOError as e:
        print(f"Error writing CSV: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
