#!/usr/bin/env python3

import json
import os
import re
import glob

def remove_newlines_from_expr(json_obj):
    """
    Recursively traverse the JSON object and remove newlines from "expr" fields.
    """
    modified = False
    
    if isinstance(json_obj, dict):
        for key, value in json_obj.items():
            if key == "expr" and isinstance(value, str):
                # Remove all newlines and unnecessary whitespace
                new_value = re.sub(r'\s*\n\s*', ' ', value)
                # Normalize spaces (no double spaces)
                new_value = re.sub(r'\s+', ' ', new_value)
                
                if new_value != value:
                    json_obj[key] = new_value
                    modified = True
            else:
                child_modified = remove_newlines_from_expr(value)
                modified = modified or child_modified
    
    elif isinstance(json_obj, list):
        for item in json_obj:
            child_modified = remove_newlines_from_expr(item)
            modified = modified or child_modified
    
    return modified

def process_dashboard_file(file_path):
    """
    Process a dashboard JSON file to remove newlines from expr fields.
    """
    print(f"Processing {file_path}...")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            dashboard = json.load(f)
        
        modified = remove_newlines_from_expr(dashboard)
        
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(dashboard, f, indent=2)
            print(f"✓ Newlines removed from expressions in {file_path}")
        else:
            print(f"- No changes needed in {file_path}")
        
        return modified
    except Exception as e:
        print(f"× Error processing {file_path}: {str(e)}")
        return False

def main():
    """
    Process all dashboard JSON files in the dashboards_out directory.
    """
    dashboard_files = glob.glob('dashboards_out/*.json')
    
    if not dashboard_files:
        print("No dashboard files found in dashboards_out directory")
        return
    
    print(f"Found {len(dashboard_files)} dashboard files")
    
    modified_count = 0
    
    for file_path in dashboard_files:
        if process_dashboard_file(file_path):
            modified_count += 1
    
    print(f"\nProcessing complete. Modified {modified_count} out of {len(dashboard_files)} files.")

if __name__ == "__main__":
    main() 