#!/usr/bin/env python3
import os
import re
import glob

def find_windows_references():
    """Search for any remaining Windows references in the libsonnet files."""
    print("\nChecking for any remaining Windows references...")
    
    # Look in all libsonnet files
    libsonnet_files = glob.glob('dashboards/**/*.libsonnet', recursive=True) + glob.glob('rules/*.libsonnet')
    
    windows_references = []
    
    for file_path in libsonnet_files:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                
                # Look for Windows references
                if re.search(r'[Ww]indows', content):
                    windows_references.append(file_path)
                    # Print the lines with Windows references
                    lines = content.split('\n')
                    for i, line in enumerate(lines):
                        if re.search(r'[Ww]indows', line):
                            print(f"{file_path}:{i+1}: {line.strip()}")
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
    
    return windows_references

def remove_references_from_resource_files():
    """Remove Windows references from resource files."""
    print("\nRemoving Windows references from resource files...")
    
    resource_files = glob.glob('dashboards/resources/*.libsonnet')
    modified_files = []
    
    for file_path in resource_files:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Check if the file has Windows references
            if re.search(r'[Ww]indows', content):
                # Remove lines with Windows references
                updated_content = re.sub(r'^.*[Ww]indows.*$\n?', '', content, flags=re.MULTILINE)
                
                # Clean up any resulting syntax issues like trailing commas
                updated_content = re.sub(r',(\s*[\]}])', r'\1', updated_content)
                
                with open(file_path, 'w') as f:
                    f.write(updated_content)
                    
                modified_files.append(file_path)
                print(f"Removed Windows references from {file_path}")
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
    
    return modified_files

def main():
    """Find and remove any remaining Windows references."""
    print("Searching for remaining Windows references...")
    
    # Find Windows references
    windows_references = find_windows_references()
    
    if not windows_references:
        print("No Windows references found!")
        return
    
    print(f"\nFound Windows references in {len(windows_references)} files.")
    
    # Remove references from resource files
    modified_files = remove_references_from_resource_files()
    
    if modified_files:
        print(f"\nRemoved Windows references from {len(modified_files)} files.")
    else:
        print("\nNo files modified.")
    
    # Check again after modifications
    print("\nChecking again for Windows references...")
    remaining_references = find_windows_references()
    
    if remaining_references:
        print(f"\nStill found Windows references in {len(remaining_references)} files.")
        print("You might need to manually edit these files to remove Windows references.")
    else:
        print("\nAll Windows references have been successfully removed!")

if __name__ == "__main__":
    main() 