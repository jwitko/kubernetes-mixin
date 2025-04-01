#!/usr/bin/env python3
import os
import re
import json
import glob
import subprocess

def extract_recording_rules():
    """Extract all recording rules and their expressions from rule files."""
    recording_rules = {}
    rule_files = glob.glob('rules/*.libsonnet')
    
    for file_path in rule_files:
        with open(file_path, 'r') as f:
            content = f.read()
            
            # Find all record blocks using regex
            matches = re.finditer(r'record:\s*[\'"]([^\'"]+)[\'"].*?expr:\s*\|\|\|(.*?)\|\|\|', 
                                 content, re.DOTALL)
            
            for match in matches:
                rule_name = match.group(1)
                expr = match.group(2).strip()
                
                # Clean up the expression (remove formatting)
                expr = re.sub(r'\s+', ' ', expr)
                expr = expr.replace(' % $._config', '')  # Remove config formatting
                
                recording_rules[rule_name] = expr
                print(f"Found recording rule: {rule_name}")
    
    return recording_rules

def replace_in_file(file_path, recording_rules):
    """Replace recording rule references with their raw expressions."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Track if any replacements were made
    replacements_made = False
    
    # Sort rule names by length (longest first) to avoid partial replacements
    rule_names = sorted(recording_rules.keys(), key=len, reverse=True)
    
    for rule_name in rule_names:
        # Only replace the rule name if it's in a prometheus query
        # This regex looks for the rule_name in a string context within prometheus queries
        pattern = f'(["\'])([^"\']*){re.escape(rule_name)}([^"\']*)(["\'])'
        
        def replace_match(match):
            nonlocal replacements_made
            full_match = match.group(0)
            quote_start = match.group(1)
            prefix = match.group(2)
            suffix = match.group(3)
            quote_end = match.group(4)
            
            # Replace with the raw expression
            replacement = f"{quote_start}{prefix}({recording_rules[rule_name]}){suffix}{quote_end}"
            
            # Compare to ensure we made a change
            if full_match != replacement:
                replacements_made = True
                print(f"  - Replacing '{rule_name}' in {file_path}")
                
            return replacement
        
        content = re.sub(pattern, replace_match, content)
    
    # Clean up any multi-line expressions in JSON to ensure they're properly formatted for Grafana
    if file_path.endswith('.json'):
        # Look for expr fields in JSON and ensure their values don't contain newlines
        try:
            data = json.loads(content)
            modified = False
            
            def clean_expr_in_object(obj):
                nonlocal modified
                if isinstance(obj, dict):
                    for key, value in obj.items():
                        if key == 'expr' and isinstance(value, str):
                            # Replace newlines and normalize whitespace
                            cleaned_value = re.sub(r'\s+', ' ', value).strip()
                            if cleaned_value != value:
                                obj[key] = cleaned_value
                                modified = True
                        elif isinstance(value, (dict, list)):
                            clean_expr_in_object(value)
                elif isinstance(obj, list):
                    for item in obj:
                        if isinstance(item, (dict, list)):
                            clean_expr_in_object(item)
            
            clean_expr_in_object(data)
            
            if modified:
                content = json.dumps(data, indent=3)
                replacements_made = True
                print(f"  - Cleaned up multi-line expressions in {file_path}")
        except json.JSONDecodeError:
            print(f"  - Warning: Could not parse JSON in {file_path}, skipping cleanup")
    
    # Write back only if changes were made
    if replacements_made:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Updated {file_path}")
    
    return replacements_made

def process_all_files(recording_rules):
    """Process all dashboard and alert files to replace recording rule references."""
    dashboard_files = glob.glob('dashboards/**/*.libsonnet', recursive=True)
    alert_files = glob.glob('alerts/*.libsonnet')
    json_files = glob.glob('dashboards_out/*.json')
    
    all_files = dashboard_files + alert_files + json_files
    
    total_files = len(all_files)
    updated_files = 0
    
    for file_path in all_files:
        print(f"Processing {file_path}...")
        if replace_in_file(file_path, recording_rules):
            updated_files += 1
    
    print(f"\nReplaced recording rules in {updated_files} out of {total_files} files.")

def disable_recording_rules():
    """Modify rules.libsonnet to skip generating recording rules."""
    # Create a backup
    os.system('cp rules/rules.libsonnet rules/rules.libsonnet.bak')
    
    # Create a new empty rules.libsonnet that doesn't include any recording rules
    with open('rules/rules.libsonnet', 'w') as f:
        f.write('{}\n')  # Empty JSON object
    
    print("Disabled recording rules generation by emptying rules.libsonnet")

def main():
    print("Extracting recording rules...")
    recording_rules = extract_recording_rules()
    print(f"Found {len(recording_rules)} recording rules\n")
    
    print("Replacing recording rules in dashboards and alerts...")
    process_all_files(recording_rules)
    
    print("\nDisabling recording rule generation...")
    disable_recording_rules()
    
    print("\nDone! Recording rules have been replaced with their raw expressions.")
    print("To regenerate files without recording rules, run the appropriate make commands.")

if __name__ == "__main__":
    main() 