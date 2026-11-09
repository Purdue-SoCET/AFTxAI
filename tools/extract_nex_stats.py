#!/usr/bin/env python3

import os
import json
import csv
import glob

def extract_stats():
    # Find all session files in ~/.nex/sessions/
    sessions_dir = os.path.expanduser("~/.nex/sessions")
    session_files = glob.glob(os.path.join(sessions_dir, "*.json"))
    
    if not session_files:
        print(f"No session files found in {sessions_dir}")
        return

    all_stats = []
    stat_keys = set()
    
    for file_path in session_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                
            # Basic session info
            session_info = {
                "id": data.get("id", ""),
                "title": data.get("title", ""),
                "created_at": data.get("created_at", "")
            }
            
            # Extract stats block if it exists
            stats = data.get("stats", {})
            for key, value in stats.items():
                session_info[key] = value
                stat_keys.add(key)
                
            all_stats.append(session_info)
            
        except Exception as e:
            print(f"Error reading {file_path}: {e}")

    if not all_stats:
        print("No valid session data extracted.")
        return

    # Prepare CSV headers
    base_headers = ["id", "created_at", "title"]
    dynamic_headers = sorted(list(stat_keys))
    headers = base_headers + [k for k in dynamic_headers if k not in base_headers]
    
    csv_file = "nex_session_stats.csv"
    
    # 1. Write raw data to CSV
    try:
        with open(csv_file, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=headers)
            writer.writeheader()
            # Sort chronologically by created_at
            for row in sorted(all_stats, key=lambda x: x["created_at"]):
                writer.writerow(row)
        print(f"Successfully extracted stats for {len(all_stats)} sessions to {csv_file}")
    except Exception as e:
        print(f"Error writing to {csv_file}: {e}")

    # 2. Calculate totals for numeric columns
    totals = {}
    sum_keys = [
        "input_tokens", "output_tokens", "cache_read_tokens", "cache_write_tokens",
        "prompts_sent", "tool_calls", "successful_tool_calls", 
        "wall_time_seconds", "answer_time_seconds"
    ]
    
    for key in sum_keys:
        totals[key] = sum(row.get(key, 0) for row in all_stats if isinstance(row.get(key), (int, float)))

    md_file = "nex_session_totals.md"
    
    # 3. Write summary to Markdown
    try:
        with open(md_file, 'w', encoding='utf-8') as mdfile:
            mdfile.write("# NEX Session Totals\n\n")
            mdfile.write(f"**Total Sessions Analyzed:** {len(all_stats)}\n\n")
            
            mdfile.write("| Metric | Total |\n")
            mdfile.write("|---|---|\n")
            
            for key in sum_keys:
                val = totals[key]
                # Format numbers with commas and round floats
                if isinstance(val, float):
                    val_str = f"{val:,.1f}"
                else:
                    val_str = f"{val:,}"
                
                # Make keys readable (e.g., "input_tokens" -> "Input Tokens")
                nice_key = key.replace("_", " ").title()
                mdfile.write(f"| {nice_key} | {val_str} |\n")
                
        print(f"Successfully wrote totals to {md_file}")
    except Exception as e:
        print(f"Error writing to {md_file}: {e}")

if __name__ == "__main__":
    extract_stats()
