#!/usr/bin/env python3
import os
import re
import glob
import json

def remove_windows_files():
    """Remove Windows-related files from rules and dashboards directories."""
    # Files to remove
    files_to_remove = [
        "rules/windows.libsonnet",
        "dashboards/windows.libsonnet"
    ]
    
    # Remove the files
    for file_path in files_to_remove:
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
                print(f"Removed file: {file_path}")
            except Exception as e:
                print(f"Error removing {file_path}: {e}")
        else:
            print(f"File not found: {file_path}")

def remove_windows_dashboards_output():
    """Remove any Windows-related dashboard output files."""
    windows_dashboards = glob.glob('dashboards_out/*windows*.json')
    
    if not windows_dashboards:
        print("No Windows dashboards found in dashboards_out/")
    else:
        for dashboard in windows_dashboards:
            try:
                os.remove(dashboard)
                print(f"Removed dashboard: {dashboard}")
            except Exception as e:
                print(f"Error removing {dashboard}: {e}")

def update_dashboard_references():
    """Update the dashboards.libsonnet file to remove Windows dashboard references."""
    dashboard_file = "dashboards/dashboards.libsonnet"
    
    if not os.path.exists(dashboard_file):
        print(f"Dashboard file not found: {dashboard_file}")
        return
    
    try:
        with open(dashboard_file, 'r') as f:
            content = f.read()
        
        # Remove references to windows dashboards
        updated_content = re.sub(r'[^,]*["\']windows["\'][^,]*,?\n', '', content)
        
        # Fix any remaining syntax issues after removal
        updated_content = re.sub(r',\s*]', '\n]', updated_content)
        
        with open(dashboard_file, 'w') as f:
            f.write(updated_content)
        
        print(f"Updated {dashboard_file} to remove Windows references")
    except Exception as e:
        print(f"Error updating {dashboard_file}: {e}")

def update_rules_references():
    """Update rules references to remove Windows rules."""
    rules_file = "rules/rules.libsonnet"
    
    if not os.path.exists(rules_file):
        print(f"Rules file not found: {rules_file}")
        return
    
    try:
        with open(rules_file, 'r') as f:
            content = f.read()
        
        # If rules.libsonnet is empty (which we did earlier), there's nothing to do
        if content.strip() == '{}' or content.strip() == '':
            print(f"Rules file {rules_file} is already empty, no Windows rules to remove")
            return
        
        # Otherwise, try to remove windows references
        updated_content = re.sub(r'[^,]*["\']windows["\'][^,]*,?\n', '', content)
        
        # Fix any remaining syntax issues after removal
        updated_content = re.sub(r',\s*]', '\n]', updated_content)
        
        with open(rules_file, 'w') as f:
            f.write(updated_content)
        
        print(f"Updated {rules_file} to remove Windows references")
    except Exception as e:
        print(f"Error updating {rules_file}: {e}")

def main():
    """Execute all removal tasks."""
    print("Removing Windows components from Kubernetes monitoring...")
    
    # Remove Windows files
    remove_windows_files()
    
    # Remove Windows dashboards output
    remove_windows_dashboards_output()
    
    # Update references in dashboards
    update_dashboard_references()
    
    # Update references in rules
    update_rules_references()
    
    print("\nDone! All Windows-related components have been removed.")
    print("Note: You may need to regenerate dashboards and rules by running appropriate make commands.")

if __name__ == "__main__":
    main() 