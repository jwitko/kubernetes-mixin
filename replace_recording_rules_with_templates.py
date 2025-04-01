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
                
                # Handle template expressions differently
                if '%s' in rule_name or '%d' in rule_name:
                    # For template rules, keep the raw expression with formatting
                    expr = expr.strip()
                else:
                    # For regular rules, remove formatting
                    expr = expr.replace(' % $._config', '')
                
                recording_rules[rule_name] = expr
                print(f"Found recording rule: {rule_name}")
    
    return recording_rules

def find_template_usage(alert_files):
    """Find templates like burnrate%s in alerts files."""
    template_usages = {}
    
    for file_path in alert_files:
        with open(file_path, 'r') as f:
            content = f.read()
            
            # Look for patterns like apiserver_request:burnrate%s
            template_matches = re.finditer(r'([a-zA-Z0-9_:]+)(%[sd])', content)
            
            for match in template_matches:
                base_name = match.group(1)
                format_spec = match.group(2)
                template_name = base_name + format_spec
                
                if template_name not in template_usages:
                    template_usages[template_name] = set()
                
                template_usages[template_name].add(file_path)
    
    return template_usages

def create_template_mappings(recording_rules, template_usages):
    """Create mappings for template rules."""
    template_mappings = {}
    
    for template_name in template_usages:
        for rule_name in recording_rules:
            if rule_name == template_name:
                expr = recording_rules[rule_name]
                template_mappings[template_name] = expr
                print(f"Found template mapping: {template_name} -> {expr}")
    
    return template_mappings

def replace_in_file(file_path, recording_rules, template_mappings=None):
    """Replace recording rule references with their raw expressions."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Track if any replacements were made
    replacements_made = False
    
    # Sort rule names by length (longest first) to avoid partial replacements
    rule_names = sorted(recording_rules.keys(), key=len, reverse=True)
    
    # First handle non-template rules
    for rule_name in rule_names:
        if '%s' not in rule_name and '%d' not in rule_name:
            # Only replace the rule name if it's in a string context within prometheus queries
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
    
    # Handle template rules separately if provided
    if template_mappings:
        for template_name, expr in template_mappings.items():
            if template_name in content:
                # Pattern to match the template in a special context like sum by() (...) 
                # This is more specific to handle apiserver_request:burnrate%s cases
                pattern = f'(["\'])([^"\']*){re.escape(template_name)}([^"\']*)(["\'])'
                
                def replace_template_match(match):
                    nonlocal replacements_made
                    full_match = match.group(0)
                    quote_start = match.group(1)
                    prefix = match.group(2)
                    suffix = match.group(3) 
                    quote_end = match.group(4)
                    
                    # Extract the template variables from the suffix if needed
                    # In your alerts, you're using a template like apiserver_request:burnrate%s
                    # where %s is replaced with a window value like "1h" 
                    
                    # For the specific case of apiserver_request:burnrate%s
                    if template_name == "apiserver_request:burnrate%s":
                        # Find what the %s is being replaced with in this context
                        # Looking for patterns like in your alerts
                        expr_copy = expr
                        # Format with a placeholder that we can replace
                        formatted_expr = f"({expr_copy})"
                        
                        replacement = f"{quote_start}{prefix}{formatted_expr}{suffix}{quote_end}"
                        
                        if full_match != replacement:
                            replacements_made = True
                            print(f"  - Replacing template '{template_name}' in {file_path}")
                        
                        return replacement
                    
                    # General case for other templates
                    formatted_expr = f"({expr})"
                    replacement = f"{quote_start}{prefix}{formatted_expr}{suffix}{quote_end}"
                    
                    if full_match != replacement:
                        replacements_made = True
                        print(f"  - Replacing template '{template_name}' in {file_path}")
                    
                    return replacement
                
                content = re.sub(pattern, replace_template_match, content)
    
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
    
    # Find template usages in alert files
    template_usages = find_template_usage(alert_files)
    template_mappings = create_template_mappings(recording_rules, template_usages)
    
    all_files = dashboard_files + alert_files
    
    total_files = len(all_files)
    updated_files = 0
    
    for file_path in all_files:
        print(f"Processing {file_path}...")
        if replace_in_file(file_path, recording_rules, template_mappings):
            updated_files += 1
    
    print(f"\nReplaced recording rules in {updated_files} out of {total_files} files.")

def disable_recording_rules():
    """Modify rules.libsonnet to skip generating recording rules."""
    # Create a backup
    os.system('cp rules/rules.libsonnet rules/rules.libsonnet.bak')
    
    # Create a new rules.libsonnet with empty groups but valid structure
    with open('rules/rules.libsonnet', 'w') as f:
        f.write('''{
  prometheusRules+:: {
    groups+: [],
  },
}
''')
    
    print("Disabled recording rules generation by updating rules.libsonnet")

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