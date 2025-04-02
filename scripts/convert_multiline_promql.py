#!/usr/bin/env python3

import os
import re
import glob
import argparse
import sys

# Regular expression to match multi-line PromQL queries in Jsonnet files
# This pattern matches:
# 1. The opening |||
# 2. All text until the closing |||
# 3. The closing ||| and any formatting (like % $._config)
MULTI_LINE_PATTERN = r'(\|\|\|\n)([\s\S]*?)(\|\|\|(?:\s*%\s*\$\._config)?)'

def convert_multiline_to_singleline(content):
    """
    Converts multi-line PromQL queries to single-line format.
    
    Args:
        content (str): The content of a Jsonnet file.
    
    Returns:
        str: The content with multi-line queries converted to single-line.
        int: The number of queries that were converted.
    """
    def replace_match(match):
        """Replace a multi-line query with a single-line version."""
        prefix = match.group(1)  # |||
        query = match.group(2)   # The actual query
        suffix = match.group(3)  # ||| and any formatting
        
        # Convert to single line - normalize whitespace
        query_single_line = re.sub(r'\s+', ' ', query.strip())
        
        # Use single quotes instead of triple pipes
        if suffix.strip() == '|||':
            return f"'{query_single_line}'"
        else:
            # Handle cases with string formatting (e.g., % $._config)
            suffix_part = suffix.replace('|||', '').strip()
            return f"'{query_single_line}' {suffix_part}"
    
    # Apply the conversion
    new_content, count = re.subn(MULTI_LINE_PATTERN, replace_match, content)
    return new_content, count

def process_file(file_path, dry_run=False):
    """
    Process a single Jsonnet file to convert multi-line queries.
    
    Args:
        file_path (str): Path to the Jsonnet file.
        dry_run (bool): If True, don't make actual changes.
    
    Returns:
        int: Number of queries converted in this file.
    """
    print(f"Processing {file_path}...")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        new_content, count = convert_multiline_to_singleline(content)
        
        if count > 0:
            print(f"  - Found {count} multi-line queries to convert")
            
            if not dry_run:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"  ✅ Converted {count} queries to single-line format")
            else:
                print(f"  ✓ Would convert {count} queries (dry run)")
        else:
            print(f"  - No multi-line queries found")
        
        return count
        
    except Exception as e:
        print(f"  ❌ Error processing {file_path}: {str(e)}")
        return 0

def main():
    parser = argparse.ArgumentParser(
        description="Convert multi-line PromQL queries in Jsonnet files to single-line format."
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
    total_converted = 0
    
    for base_path in args.paths:
        if os.path.isdir(base_path):
            # Find all Jsonnet files in the directory
            file_pattern = os.path.join(base_path, "**", "*.libsonnet")
            files = glob.glob(file_pattern, recursive=True)
            
            print(f"Found {len(files)} Jsonnet files in {base_path}")
            
            for file_path in files:
                converted = process_file(file_path, args.dry_run)
                if converted > 0:
                    total_files += 1
                    total_converted += converted
        elif os.path.isfile(base_path) and base_path.endswith(".libsonnet"):
            # Process a single file
            converted = process_file(base_path, args.dry_run)
            if converted > 0:
                total_files += 1
                total_converted += converted
        else:
            print(f"Invalid path: {base_path}")
    
    print(f"\nSummary: Converted {total_converted} multi-line queries in {total_files} files")
    if args.dry_run:
        print("(Dry run - no files were modified)")

if __name__ == "__main__":
    main() 