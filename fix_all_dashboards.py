#!/usr/bin/env python3
import os
import json
import re
import glob

def fix_expressions(content):
    """Fix specific expression issues in dashboard JSON content."""
    # Fix spaces around operators
    content = re.sub(r'\s*=\s*', '=', content)
    content = re.sub(r'\s*!\s*=\s*', '!=', content)
    content = re.sub(r'\s*~\s*', '~', content)
    
    # Fix specific expressions that commonly cause issues
    content = content.replace('job = \"kubelet\"', 'job="kubelet"')
    content = content.replace('image ! = \"\"', 'image!=""')
    content = content.replace('node ! = \"\"', 'node!=""')
    content = content.replace('job = \"kube - state - metrics\"', 'job="kube-state-metrics"')
    content = content.replace('owner_kind = \"Job\"', 'owner_kind="Job"')
    content = content.replace('\"workload\", \"$1\", \"owner_name\", \"(. *)\"', '"workload", "$1", "owner_name", "(.*)"')
    content = content.replace('cluster = \"$cluster\"', 'cluster="$cluster"')
    content = content.replace('namespace = \"$namespace\"', 'namespace="$namespace"')
    content = content.replace('workload_type = ~\"$type\"', 'workload_type=~"$type"')
    content = content.replace('type = \"hard\"', 'type="hard"')
    content = content.replace('resource = ~\"', 'resource=~"')
    
    return content

def process_dashboard_file(file_path):
    """Process a single dashboard file, fixing expression issues."""
    print(f"Processing {file_path}...")
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Apply fixes to content
        fixed_content = fix_expressions(content)
        
        # Only write back if changes were made
        if content != fixed_content:
            with open(file_path, 'w') as f:
                f.write(fixed_content)
            print(f"  - Made changes to {file_path}")
        else:
            print(f"  - No changes needed in {file_path}")
        
        # Verify that the JSON is valid
        try:
            with open(file_path, 'r') as f:
                json.load(f)
            print(f"  - JSON is valid")
            return True
        except json.JSONDecodeError as e:
            print(f"  - Error: JSON is still invalid: {e}")
            return False
            
    except Exception as e:
        print(f"  - Error processing {file_path}: {e}")
        return False

def main():
    print("Checking and fixing all dashboards...")
    dashboard_files = glob.glob('dashboards_out/*.json')
    
    total_files = len(dashboard_files)
    valid_files = 0
    fixed_files = 0
    
    for file_path in dashboard_files:
        result = process_dashboard_file(file_path)
        if result:
            valid_files += 1
            fixed_files += 1
    
    print(f"\nSummary:")
    print(f"  - Processed {total_files} dashboard files")
    print(f"  - {valid_files} files are now valid JSON")
    print(f"  - {fixed_files} files were fixed")
    
    if valid_files == total_files:
        print("\nAll dashboards have been successfully fixed and validated!")
    else:
        print(f"\nWarning: {total_files - valid_files} dashboard files still have issues.")
    
    print("\nThe dashboards should now work correctly in Grafana.")

if __name__ == "__main__":
    main() 