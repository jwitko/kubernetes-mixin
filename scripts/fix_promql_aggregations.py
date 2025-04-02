#!/usr/bin/env python3

import os
import re
import glob
import argparse
import sys

def fix_aggregation_syntax(content):
    """
    Fix PromQL syntax by moving 'by (label)' from after the closing parenthesis
    to before the aggregation function, with more careful parsing to avoid breaking expressions.
    
    Args:
        content (str): The content of a Jsonnet file
        
    Returns:
        str: The content with fixed PromQL syntax
        int: The number of fixes applied
    """
    # This pattern targets expressions in single-quoted strings that likely include PromQL
    # We'll then process the PromQL syntax within these strings
    string_pattern = r"'([^']*\)\s*by\s*\([^)]+\)[^']*)'"
    
    def process_string(match):
        """Process a single-quoted string to fix PromQL syntax issues"""
        promql = match.group(1)
        
        # Pattern to find aggregation functions followed by by-clause after parentheses
        # This is more careful to match balanced parentheses
        agg_pattern = r'(sum|count|min|max|avg|group|stddev|stdvar|topk|bottomk|quantile)\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*by\s*\(([^)]+)\)'
        
        def fix_aggregation(agg_match):
            """Fix a single aggregation with by-clause"""
            fn = agg_match.group(1)          # Aggregation function
            expr = agg_match.group(2)        # Expression inside parentheses (may include nested parentheses)
            by_labels = agg_match.group(3)   # Labels in by-clause
            
            # Reconstruct with correct syntax
            return f"{fn} by ({by_labels}) ({expr})"
        
        # Make the fixes
        fixed_promql, count = re.subn(agg_pattern, fix_aggregation, promql)
        return "'" + fixed_promql + "'", count
    
    # Apply fixes to all matching strings in the content
    total_count = 0
    result = content
    
    # Find each string with potential PromQL
    matches = re.finditer(string_pattern, content)
    for match in matches:
        full_match = match.group(0)
        fixed_string, count = process_string(match)
        
        if count > 0:
            # Replace only if we actually made changes
            result = result.replace(full_match, fixed_string, 1)
            total_count += count
    
    return result, total_count

def process_file(file_path, dry_run=False):
    """
    Process a single Jsonnet file to fix PromQL syntax.
    
    Args:
        file_path (str): Path to the Jsonnet file
        dry_run (bool): If True, don't make actual changes
        
    Returns:
        int: Number of fixes applied to this file
    """
    print(f"Processing {file_path}...")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        new_content, count = fix_aggregation_syntax(content)
        
        if count > 0:
            print(f"  - Found {count} aggregation expressions to fix")
            
            if not dry_run:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"  ✅ Fixed {count} aggregation expressions")
            else:
                print(f"  ✓ Would fix {count} aggregation expressions (dry run)")
        else:
            print(f"  - No issues found")
        
        return count
        
    except Exception as e:
        print(f"  ❌ Error processing {file_path}: {str(e)}")
        return 0

def main():
    parser = argparse.ArgumentParser(
        description="Fix PromQL aggregation syntax in Jsonnet files."
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="Show what would be changed without making actual changes"
    )
    parser.add_argument(
        "paths", 
        nargs="*", 
        default=["dashboards"],
        help="Paths to search for Jsonnet files (defaults to 'dashboards')"
    )
    args = parser.parse_args()
    
    total_files = 0
    total_fixed = 0
    
    for base_path in args.paths:
        if os.path.isdir(base_path):
            # Find all Jsonnet files in the directory
            file_pattern = os.path.join(base_path, "**", "*.libsonnet")
            files = glob.glob(file_pattern, recursive=True)
            
            print(f"Found {len(files)} Jsonnet files in {base_path}")
            
            for file_path in files:
                fixed = process_file(file_path, args.dry_run)
                if fixed > 0:
                    total_files += 1
                    total_fixed += fixed
        elif os.path.isfile(base_path) and base_path.endswith(".libsonnet"):
            # Process a single file
            fixed = process_file(base_path, args.dry_run)
            if fixed > 0:
                total_files += 1
                total_fixed += fixed
        else:
            print(f"Invalid path: {base_path}")
    
    print(f"\nSummary: Fixed {total_fixed} aggregation expressions in {total_files} files")
    if args.dry_run:
        print("(Dry run - no files were modified)")

if __name__ == "__main__":
    main() 