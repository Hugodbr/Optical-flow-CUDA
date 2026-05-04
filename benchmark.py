#!/usr/bin/env python3
import argparse
import csv
import os
import re
import statistics
import subprocess
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
GPU_BINARY = BASE_DIR / "build" / "optical_flow"
CPU_BINARY = BASE_DIR / "CPU" / "build_cpu" / "optical_flow_cpu"
VIDEO_PATH = BASE_DIR / "build" / "video.mp4"
CONFIG_PATH = BASE_DIR / "config" / "camera.yaml"
CSV_PATH = BASE_DIR / "resultados.csv"
FRAMES_CSV_PATH = BASE_DIR / "frames.csv"
PLOTS_DIR = BASE_DIR / "plots"
FPS_PLOT = PLOTS_DIR / "fps_comparison.png"
TIME_PLOT = PLOTS_DIR / "total_time_comparison.png"
FRAMES_PLOT = PLOTS_DIR / "frame_times.png"

RESULT_KEY_PATTERN = re.compile(r"BENCHMARK_RESULT,(.*)")
FRAME_KEY_PATTERN = re.compile(r"FRAME,(.*)")


def parse_benchmark_result(text):
    for line in text.splitlines():
        match = RESULT_KEY_PATTERN.search(line)
        if match:
            data = {}
            for item in match.group(1).split(','):
                if '=' not in item:
                    continue
                key, value = item.split('=', 1)
                data[key.strip()] = value.strip()
            return data
    return None


def parse_frame_results(text, tipo):
    frames = []
    for line in text.splitlines():
        match = FRAME_KEY_PATTERN.search(line)
        if match:
            data = {}
            for item in match.group(1).split(','):
                if '=' not in item:
                    continue
                key, value = item.split('=', 1)
                data[key.strip()] = value.strip()
            if data:
                frames.append({
                    "tipo": tipo,
                    "frame_id": int(data.get("id", 0)),
                    "time_ms": float(data.get("time_ms", 0.0)),
                    "exceeds": int(data.get("exceeds", 0)),
                })
    return frames


def run_process(command, label, timeout):
    print(f"Running {label}: {' '.join(command)}")
    try:
        result = subprocess.run(
            command,
            cwd=BASE_DIR,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"{label} timed out after {timeout} seconds") from exc

    output = "\n".join(filter(None, [result.stdout, result.stderr]))
    if result.returncode != 0:
        raise RuntimeError(
            f"{label} failed with exit code {result.returncode}\nOutput:\n{output}"
        )

    parsed = parse_benchmark_result(output)
    if parsed is None:
        raise RuntimeError(f"{label} did not emit benchmark result. Output:\n{output}")

    frames = parse_frame_results(output, label)

    return {"result": parsed, "frames": frames}


def write_csv(rows, path):
    fieldnames = ["tipo", "run", "tiempo_total", "fps", "tiempo_por_frame", "frames"]
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_frames_csv(frames, path):
    fieldnames = ["tipo", "frame_id", "time_ms", "exceeds"]
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for frame in frames:
            writer.writerow(frame)


def read_csv(path):
    rows = []
    with open(path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "tipo": row["tipo"],
                "run": int(row["run"]),
                "tiempo_total": float(row["tiempo_total"]),
                "fps": float(row["fps"]),
                "tiempo_por_frame": float(row["tiempo_por_frame"]),
                "frames": int(row["frames"]),
            })
    return rows


def summary_by_type(rows):
    summary = {}
    for tipo in sorted({row["tipo"] for row in rows}):
        items = [row for row in rows if row["tipo"] == tipo]
        fps = [row["fps"] for row in items]
        total_time = [row["tiempo_total"] for row in items]
        summary[tipo] = {
            "runs": len(items),
            "fps_mean": statistics.mean(fps) if fps else 0.0,
            "fps_std": statistics.stdev(fps) if len(fps) > 1 else 0.0,
            "time_mean": statistics.mean(total_time) if total_time else 0.0,
            "time_std": statistics.stdev(total_time) if len(total_time) > 1 else 0.0,
        }
    return summary


def plot_results(csv_path, fps_path, time_path, frames_path, frames_csv_path):
    try:
        import matplotlib.pyplot as plt
    except ImportError as exc:
        raise RuntimeError("matplotlib is required to generate plots. Install it with 'pip install matplotlib'.") from exc

    rows = read_csv(csv_path)
    summary = summary_by_type(rows)

    tipos = list(summary.keys())
    fps_means = [summary[t]["fps_mean"] for t in tipos]
    fps_std = [summary[t]["fps_std"] for t in tipos]
    time_means = [summary[t]["time_mean"] for t in tipos]
    time_std = [summary[t]["time_std"] for t in tipos]

    PLOTS_DIR.mkdir(parents=True, exist_ok=True)

    plt.figure(figsize=(8, 5))
    plt.bar(tipos, fps_means, yerr=fps_std, capsize=8, color=["tab:blue", "tab:orange"])
    plt.title("Comparación de FPS promedio: GPU vs CPU")
    plt.xlabel("Versión")
    plt.ylabel("FPS promedio")
    plt.grid(axis="y", linestyle="--", alpha=0.4)
    for i, v in enumerate(fps_means):
        plt.text(i, v + max(fps_std) * 0.05 if fps_std else v + 0.05, f"{v:.2f}", ha="center", va="bottom")
    plt.tight_layout()
    plt.savefig(fps_path)
    print(f"Saved FPS plot to {fps_path}")
    plt.close()

    plt.figure(figsize=(8, 5))
    plt.bar(tipos, time_means, yerr=time_std, capsize=8, color=["tab:green", "tab:red"])
    plt.title("Comparación de tiempo total de ejecución: GPU vs CPU")
    plt.xlabel("Versión")
    plt.ylabel("Tiempo total (segundos)")
    plt.grid(axis="y", linestyle="--", alpha=0.4)
    for i, v in enumerate(time_means):
        plt.text(i, v + max(time_std) * 0.05 if time_std else v + 0.05, f"{v:.2f}s", ha="center", va="bottom")
    plt.tight_layout()
    plt.savefig(time_path)
    print(f"Saved time comparison plot to {time_path}")
    plt.close()

    # Plot frame times
    frames = []
    with open(frames_csv_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            frames.append({
                "tipo": row["tipo"],
                "frame_id": int(row["frame_id"]),
                "time_ms": float(row["time_ms"]),
                "exceeds": int(row["exceeds"]),
            })

    gpu_frames = [f for f in frames if f["tipo"] == "GPU"]
    cpu_frames = [f for f in frames if f["tipo"] == "CPU"]

    plt.figure(figsize=(12, 6))
    if gpu_frames:
        plt.plot([f["frame_id"] for f in gpu_frames], [f["time_ms"] for f in gpu_frames], label="GPU", color="tab:blue", linewidth=1)
    if cpu_frames:
        plt.plot([f["frame_id"] for f in cpu_frames], [f["time_ms"] for f in cpu_frames], label="CPU", color="tab:orange", linewidth=1)
    
    target_ms = 1000.0 / 30.0  # 30 FPS
    plt.axhline(y=target_ms, color='red', linestyle='--', label=f'Real-time limit ({target_ms:.1f} ms)', linewidth=2)
    
    plt.title("Tiempo de procesamiento por frame: GPU vs CPU")
    plt.xlabel("Frame ID")
    plt.ylabel("Tiempo por frame (ms)")
    plt.legend()
    plt.grid(axis="y", linestyle="--", alpha=0.4)
    plt.tight_layout()
    plt.savefig(frames_path)
    print(f"Saved frame times plot to {frames_path}")
    plt.close()


def main():
    parser = argparse.ArgumentParser(description="Benchmark GPU and CPU optical flow executables.")
    parser.add_argument("--runs", type=int, default=3, help="Number of sequential runs per version")
    parser.add_argument("--seconds", type=int, default=10, help="Benchmark duration per run in seconds")
    parser.add_argument("--csv", type=Path, default=CSV_PATH, help="Output CSV path")
    parser.add_argument("--plot-only", action="store_true", help="Only generate plots from existing CSV")
    parser.add_argument("--gpu-binary", type=Path, default=GPU_BINARY, help="GPU executable path")
    parser.add_argument("--cpu-binary", type=Path, default=CPU_BINARY, help="CPU executable path")
    parser.add_argument("--video", type=Path, default=VIDEO_PATH, help="Video input path")
    parser.add_argument("--config", type=Path, default=CONFIG_PATH, help="Camera config path")
    args = parser.parse_args()

    if args.plot_only:
        plot_results(args.csv, FPS_PLOT, TIME_PLOT, FRAMES_PLOT, FRAMES_CSV_PATH)
        return

    if not args.gpu_binary.exists():
        raise FileNotFoundError(f"GPU binary not found: {args.gpu_binary}")
    if not args.cpu_binary.exists():
        raise FileNotFoundError(f"CPU binary not found: {args.cpu_binary}")
    if not args.video.exists():
        raise FileNotFoundError(f"Video file not found: {args.video}")
    if not args.config.exists():
        raise FileNotFoundError(f"Config file not found: {args.config}")

    rows = []
    all_frames = []
    for tipo, binary in [("GPU", args.gpu_binary), ("CPU", args.cpu_binary)]:
        for run_index in range(1, args.runs + 1):
            command = [str(binary), "--config", str(args.config), "--camera", str(args.video), "--benchmark-seconds", str(args.seconds), "--headless"]
            result_data = run_process(command, tipo, timeout=args.seconds + 30)
            parsed = result_data["result"]
            frames = result_data["frames"]
            row = {
                "tipo": tipo,
                "run": run_index,
                "tiempo_total": float(parsed.get("total_time", 0.0)),
                "fps": float(parsed.get("fps", 0.0)),
                "tiempo_por_frame": float(parsed.get("time_per_frame", 0.0)),
                "frames": int(parsed.get("frames", 0)),
            }
            rows.append(row)
            all_frames.extend(frames)
            print(f"{tipo} run {run_index}: {row}")

    write_csv(rows, args.csv)
    print(f"Saved benchmark results to {args.csv}")

    write_frames_csv(all_frames, FRAMES_CSV_PATH)
    print(f"Saved frame times to {FRAMES_CSV_PATH}")

    plot_results(args.csv, FPS_PLOT, TIME_PLOT, FRAMES_PLOT, FRAMES_CSV_PATH)

    summary = summary_by_type(rows)
    print("\nSummary:")
    for tipo, stats in summary.items():
        print(f"  {tipo}: average FPS={stats['fps_mean']:.2f} ± {stats['fps_std']:.2f}, total_time={stats['time_mean']:.2f}s ± {stats['time_std']:.2f}s")

if __name__ == "__main__":
    main()
