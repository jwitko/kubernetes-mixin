#!/usr/bin/env python3

import json
import os
import re
import glob

def is_balanced_parentheses(expr):
    """
    Check if parentheses in the expression are balanced.
    Returns True if balanced, False otherwise.
    """
    stack = []
    for char in expr:
        if char == '(':
            stack.append(char)
        elif char == ')':
            if not stack:
                return False
            stack.pop()
    
    return len(stack) == 0

def fix_misplaced_filters(expr):
    """
    Fix PromQL expressions where filters like {cluster="$cluster"} are incorrectly
    positioned after closing parentheses by moving them inside the appropriate subexpression.
    """
    # Pattern to match incorrectly positioned filter expressions after closing parentheses
    # For example: sum((... some expression ...)){cluster="$cluster"} by (namespace)
    pattern = r'\)\s*(\{[^}]+\})\s*(by|group_by|without|offset|@|\[)'
    
    # If the pattern exists, we need to fix it
    if re.search(pattern, expr):
        # Find the deepest nested closing parenthesis before the filter
        parts = re.split(pattern, expr, 1)
        if len(parts) >= 3:
            before_filter = parts[0]
            filter_expr = parts[1]
            after_filter = parts[2:]
            
            # Find the matching opening parenthesis for the last closing parenthesis
            last_closing_index = before_filter.rindex(')')
            stack = []
            opening_index = -1
            
            for i in range(last_closing_index, -1, -1):
                if before_filter[i] == ')':
                    stack.append(i)
                elif before_filter[i] == '(' and stack:
                    stack.pop()
                    if not stack:
                        opening_index = i
                        break
            
            if opening_index >= 0:
                # Reconstruct the expression with the filter moved inside
                expr_parts = []
                expr_parts.append(before_filter[:opening_index+1])  # Up to and including the opening parenthesis
                
                # Now we need to find the first metric or function after the opening parenthesis
                # and insert the filter there
                inner_expr = before_filter[opening_index+1:last_closing_index]
                
                # Find the first metric or function - it might already have a filter
                metric_pattern = r'([a-zA-Z_:][a-zA-Z0-9_:]*)\s*(\{[^}]*\})?'
                metric_match = re.search(metric_pattern, inner_expr)
                
                if metric_match:
                    metric_name = metric_match.group(1)
                    existing_filter = metric_match.group(2) or ''
                    
                    if existing_filter:
                        # Merge the filters by combining their contents
                        new_filter = merge_filters(existing_filter, filter_expr)
                        inner_expr = inner_expr.replace(existing_filter, new_filter, 1)
                    else:
                        # Insert the filter after the metric name
                        inner_expr = inner_expr.replace(metric_name, metric_name + filter_expr, 1)
                
                expr_parts.append(inner_expr)
                expr_parts.append(')')  # Close the parenthesis
                
                # Add the remainder of the expression after the filter
                expr_parts.append(' ' + ' '.join(after_filter))
                
                return ''.join(expr_parts)
    
    # Fix any "unexpected by" errors - ensure by clause is correctly positioned
    # Pattern to match incorrectly positioned 'by' clauses
    by_pattern = r'([^\s,]+)\s+by\s*\('
    by_match = re.search(by_pattern, expr)
    if by_match:
        # Check if the preceding token isn't an aggregation function or has an incorrect filter placement
        preceding_token = by_match.group(1)
        if not re.match(r'(sum|avg|min|max|count|group|topk|bottomk)$', preceding_token):
            # Try to find the aggregation function and move the 'by' clause to the correct position
            agg_pattern = r'(sum|avg|min|max|count|group|topk|bottomk)\s*\('
            agg_match = re.search(agg_pattern, expr)
            if agg_match:
                # Reconstruct with proper 'by' placement
                agg_function = agg_match.group(1)
                agg_start = expr.find(agg_function)
                expr = expr[:agg_start] + agg_function + ' by' + expr[agg_start+len(agg_function):].replace(' by', '', 1)
                return expr
    
    # Fix issues with parentheses at the beginning of expressions
    # For example: (metric{filter}) by (label) could cause "unexpected ("
    if expr.startswith('(') and not expr.startswith('(sum') and not expr.startswith('(avg') and not expr.startswith('(min') and not expr.startswith('(max'):
        # Check if there's a by clause after the closing parenthesis
        by_after_paren = re.search(r'\)\s+(by|group_by|without)\s*\(', expr)
        if by_after_paren:
            # Find the matching closing parenthesis
            closing_idx = -1
            stack = []
            for i, char in enumerate(expr):
                if char == '(':
                    stack.append(i)
                elif char == ')':
                    if stack:
                        opening_idx = stack.pop()
                        if not stack:  # This is the outermost parenthesis
                            closing_idx = i
                            break
            
            if closing_idx > 0:
                # Get the actual expression inside the parentheses
                inner_expr = expr[1:closing_idx]
                # Get what comes after the closing parenthesis
                after_paren = expr[closing_idx+1:]
                # Check if this looks like it should be an aggregation
                if ' by' in after_paren:
                    # Convert to a sum by or avg by depending on what seems most appropriate
                    # Default to sum if not clear
                    expr = 'sum' + after_paren + ' (' + inner_expr + ')'
                    return expr
    
    return expr

def merge_filters(filter1, filter2):
    """
    Merge two PromQL filters by combining their label matchers.
    Example: {a="1"} and {b="2"} become {a="1",b="2"}
    """
    # Extract the contents of each filter (remove the braces)
    content1 = filter1.strip()[1:-1]
    content2 = filter2.strip()[1:-1]
    
    # Combine the contents
    if content1 and content2:
        return '{' + content1 + ',' + content2 + '}'
    elif content1:
        return '{' + content1 + '}'
    else:
        return '{' + content2 + '}'

def remove_newlines_from_expr(json_obj):
    """
    Recursively traverse the JSON object and remove newlines from "expr" fields.
    Also ensures parentheses are balanced and fixes misplaced filters.
    """
    modified = False
    
    if isinstance(json_obj, dict):
        for key, value in json_obj.items():
            if key == "expr" and isinstance(value, str):
                # Remove all newlines and unnecessary whitespace
                new_value = re.sub(r'\s*\n\s*', ' ', value)
                # Normalize spaces (no double spaces)
                new_value = re.sub(r'\s+', ' ', new_value)
                
                # Fix misplaced filters
                fixed_value = fix_misplaced_filters(new_value)
                if fixed_value != new_value:
                    print(f"Fixed misplaced filter in expression: {new_value[:50]}...")
                    new_value = fixed_value
                    modified = True
                
                # Check if parentheses are balanced
                if not is_balanced_parentheses(new_value):
                    print(f"Warning: Unbalanced parentheses detected in expression: {new_value[:50]}...")
                    # Try to fix by counting and adding missing closing parentheses
                    open_count = new_value.count('(')
                    close_count = new_value.count(')')
                    if open_count > close_count:
                        # Add missing closing parentheses
                        new_value += ')' * (open_count - close_count)
                        print(f"Fixed by adding {open_count - close_count} closing parentheses")
                        modified = True
                
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
            print(f"✓ Changes made to expressions in {file_path}")
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