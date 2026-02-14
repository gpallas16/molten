#!/usr/bin/env python3
"""
Adaptive Colors Service - Batch screen sampling

Watches a registration file for active regions, captures them in batch,
and writes results to an output file.

Input:  /tmp/molten-adaptive-regions.json
        { "notch": {"x": 100, "y": 900, "w": 400, "h": 60}, ... }

Output: /tmp/molten-adaptive-colors.json  
        { "notch": {"isDark": true, "luminance": 0.32}, ... }
"""

import os
import json
import subprocess
import time

# File paths
REGIONS_FILE = "/tmp/molten-adaptive-regions.json"
OUTPUT_FILE = "/tmp/molten-adaptive-colors.json"

# Poll interval
POLL_INTERVAL = 0.4  # 400ms


def capture_region(x: int, y: int, w: int, h: int) -> float:
    """Capture a screen region and calculate average luminance using grim."""
    try:
        cmd = ["grim", "-g", f"{x},{y} {w}x{h}", "-t", "ppm", "-"]
        result = subprocess.run(cmd, capture_output=True, timeout=1)
        
        if result.returncode != 0:
            return 0.5
        
        data = result.stdout
        lines = data.split(b'\n', 3)
        if len(lines) < 4 or lines[0] != b'P6':
            return 0.5
        
        try:
            maxval = int(lines[2].decode())
            pixel_data = lines[3]
        except (ValueError, IndexError):
            return 0.5
        
        # Sample pixels for speed
        total_luminance = 0.0
        sample_count = 0
        step = 30  # Every 10 pixels
        
        for i in range(0, min(len(pixel_data) - 2, 10000), step):
            r = pixel_data[i] / maxval
            g = pixel_data[i + 1] / maxval
            b = pixel_data[i + 2] / maxval
            luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            total_luminance += luminance
            sample_count += 1
        
        return total_luminance / sample_count if sample_count > 0 else 0.5
        
    except Exception:
        return 0.5


def read_regions() -> dict:
    """Read the regions registration file."""
    try:
        if os.path.exists(REGIONS_FILE):
            with open(REGIONS_FILE, 'r') as f:
                return json.load(f)
    except (json.JSONDecodeError, IOError):
        pass
    return {}


def write_results(results: dict):
    """Write results to output file atomically."""
    try:
        tmp_file = OUTPUT_FILE + ".tmp"
        with open(tmp_file, 'w') as f:
            json.dump(results, f)
        os.rename(tmp_file, OUTPUT_FILE)
    except IOError:
        pass


def process_regions(regions: dict) -> dict:
    """Process all regions and return results."""
    results = {}
    
    for region_id, coords in regions.items():
        try:
            x = int(coords.get('x', 0))
            y = int(coords.get('y', 0))
            w = int(coords.get('w', 100))
            h = int(coords.get('h', 50))
            
            # Bounds check
            if w < 10 or h < 10 or x < 0 or y < 0:
                continue
            w = min(w, 2000)
            h = min(h, 500)
            
            luminance = capture_region(x, y, w, h)
            results[region_id] = {
                'isDark': luminance < 0.5,
                'luminance': round(luminance, 3)
            }
            
        except (TypeError, ValueError):
            continue
    
    return results


def main():
    """Main service loop."""
    print(f"Adaptive colors service started (polling every {int(POLL_INTERVAL*1000)}ms)")
    print(f"  Input:  {REGIONS_FILE}")
    print(f"  Output: {OUTPUT_FILE}")
    
    # Initialize files
    write_results({})
    
    while True:
        try:
            regions = read_regions()
            
            if regions:
                results = process_regions(regions)
                write_results(results)
            
            time.sleep(POLL_INTERVAL)
            
        except KeyboardInterrupt:
            print("\nShutting down...")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(1)


if __name__ == "__main__":
    main()
