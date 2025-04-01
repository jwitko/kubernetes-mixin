#!/usr/bin/env python3
import json
import re

def fix_expressions(file_path):
    """Fix specific expression issues in the workloads namespace dashboard."""
    print(f"Fixing expressions in {file_path}...")
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Fix spaces around operators
        content = re.sub(r'\s*=\s*', '=', content)
        content = re.sub(r'\s*!\s*=\s*', '!=', content)
        content = re.sub(r'\s*~\s*', '~', content)
        
        # Fix specific expressions in this dashboard
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
        
        # Write back the fixed content
        with open(file_path, 'w') as f:
            f.write(content)
        
        # Verify that the JSON is now valid
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            print(f"Successfully fixed {file_path} - JSON is now valid")
            return True
        except json.JSONDecodeError as e:
            print(f"Error: JSON is still invalid after fixes: {e}")
            return False
            
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

if __name__ == "__main__":
    dashboard_path = "dashboards_out/k8s-resources-workloads-namespace.json"
    fix_expressions(dashboard_path) 