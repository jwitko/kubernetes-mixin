#!/usr/bin/env python3
import os
import re
import json
import glob

def clean_expressions(expr):
    """Clean up PromQL expressions to ensure they're properly formatted."""
    # Remove newlines and excess whitespace
    expr = re.sub(r'\s+', ' ', expr).strip()
    
    # Fix template placeholders - replace %(...) with actual values
    expr = expr.replace('%(clusterLabel)s', 'cluster')
    expr = expr.replace('%(nodeExporterSelector)s', 'job="node-exporter"')
    expr = re.sub(r'%\([^)]+\)s', '', expr)  # Remove any remaining templates
    
    # Escape double quotes within expressions that are already within double quotes
    if expr.count('"') % 2 != 0:
        # Find unescaped quotes in the middle of the string and escape them
        expr = re.sub(r'(?<=[^\\])"(?=[^"]*"[^"]*$)', r'\"', expr)
    
    # Balance parentheses and braces
    open_count = expr.count('(')
    close_count = expr.count(')')
    if open_count > close_count:
        expr = expr + ')' * (open_count - close_count)
    elif close_count > open_count:
        expr = '(' * (close_count - open_count) + expr
    
    # Fix common aggregation syntax issues - ensure space after comma in aggregations
    expr = re.sub(r'(\w+)\s*by\s*\(\s*([^)]+)\s*\)', r'\1 by (\2)', expr)
    
    # Remove any double braces that might cause issues in Grafana
    expr = expr.replace('{{', '{').replace('}}', '}')
    
    return expr

def process_dashboard_file(file_path):
    """Process a single dashboard file, fixing expression issues."""
    print(f"Processing {file_path}...")
    
    try:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                
                # First fix any templating issues that might break JSON parsing
                content = content.replace('mode!=\"idle\"', 'mode!="idle"')
                content = content.replace('mode!=\"iowait\"', 'mode!="iowait"')
                content = content.replace('mode!=\"steal\"', 'mode!="steal"')
                
                # Fix common JSON parsing issues
                content = re.sub(r',\s*\]', ']', content)  # Remove trailing commas in arrays
                content = re.sub(r',\s*\}', '}', content)  # Remove trailing commas in objects
                
                try:
                    data = json.loads(content)
                except json.JSONDecodeError as e:
                    print(f"  - Error: Could not parse JSON in {file_path}: {e}")
                    # Try to fix the JSON more aggressively
                    content = re.sub(r'\\(?!["\\/bfnrt]|u[0-9a-fA-F]{4})', r'', content)
                    try:
                        data = json.loads(content)
                        print(f"  - Successfully fixed JSON parsing issues")
                    except json.JSONDecodeError as e2:
                        print(f"  - Still can't parse JSON after fixes: {e2}")
                        return False
        except Exception as e:
            print(f"  - Error reading file {file_path}: {e}")
            return False
        
        modified = False
        
        # Process all panels
        if 'panels' in data:
            for panel in data.get('panels', []):
                # Process targets in panels
                if 'targets' in panel:
                    for target in panel.get('targets', []):
                        if 'expr' in target and target['expr']:
                            original_expr = target['expr']
                            cleaned_expr = clean_expressions(original_expr)
                            if original_expr != cleaned_expr:
                                target['expr'] = cleaned_expr
                                modified = True
                                print(f"  - Fixed expression in panel '{panel.get('title', 'Unknown')}'")
                
                # Also check for nested panels (rows)
                if 'panels' in panel:
                    for subpanel in panel.get('panels', []):
                        if 'targets' in subpanel:
                            for target in subpanel.get('targets', []):
                                if 'expr' in target and target['expr']:
                                    original_expr = target['expr']
                                    cleaned_expr = clean_expressions(original_expr)
                                    if original_expr != cleaned_expr:
                                        target['expr'] = cleaned_expr
                                        modified = True
                                        print(f"  - Fixed expression in subpanel '{subpanel.get('title', 'Unknown')}'")
        
        if modified:
            with open(file_path, 'w') as f:
                json.dump(data, f, indent=3)
            print(f"  - Successfully updated {file_path}")
            return True
        else:
            print(f"  - No changes needed in {file_path}")
            return False
            
    except Exception as e:
        print(f"  - Error processing {file_path}: {e}")
        return False

def fix_multicluster_dashboard():
    """Special handling for the multicluster dashboard which has template issues."""
    file_path = 'dashboards_out/k8s-resources-multicluster.json'
    
    if not os.path.exists(file_path):
        print(f"Multicluster dashboard not found: {file_path}")
        return False
    
    print(f"Special handling for multicluster dashboard...")
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Fix specific issues with escaping in the multicluster dashboard
        content = content.replace('mode!=\"idle\",mode!=\"iowait\",mode!=\"steal\"', 'mode!="idle",mode!="iowait",mode!="steal"')
        
        # Write back the fixed content
        with open(file_path, 'w') as f:
            f.write(content)
        
        # Now try to process it normally
        return process_dashboard_file(file_path)
        
    except Exception as e:
        print(f"  - Error fixing multicluster dashboard: {e}")
        return False

def remove_windows_dashboards():
    """Remove all Windows-related dashboard files."""
    windows_dashboards = glob.glob('dashboards_out/*windows*.json')
    
    if not windows_dashboards:
        print("No Windows dashboards found to remove.")
        return
    
    print(f"Removing {len(windows_dashboards)} Windows-related dashboards:")
    for dashboard in windows_dashboards:
        try:
            os.remove(dashboard)
            print(f"  - Removed {dashboard}")
        except Exception as e:
            print(f"  - Error removing {dashboard}: {e}")

def main():
    # First remove Windows dashboards
    print("Removing Windows-related dashboards...")
    remove_windows_dashboards()
    
    # Special handling for multicluster dashboard
    fix_multicluster_dashboard()
    
    # Process all dashboard files
    print("\nCleaning expressions in dashboard files...")
    dashboard_files = glob.glob('dashboards_out/*.json')
    
    total_files = len(dashboard_files)
    updated_files = 0
    
    for file_path in dashboard_files:
        # Skip the multicluster dashboard as we already handled it
        if 'multicluster' in file_path:
            continue
            
        if process_dashboard_file(file_path):
            updated_files += 1
    
    print(f"\nSuccessfully fixed expressions in {updated_files} out of {total_files} dashboard files.")
    print("Done! Your dashboards should now work correctly in Grafana.")

if __name__ == "__main__":
    main() 