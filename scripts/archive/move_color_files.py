#!/usr/bin/env python3
"""
Script to move all color files from flashcard image style directories to an archive.
Color files are identified by ending with color names like _blue.png, _red.png, etc.
"""

from pathlib import Path
# import shutil
import argparse
from typing import List

# Color names to identify color files
COLOR_NAMES = [
    "black", "blue", "brown", "gray", "green", 
    "orange", "pink", "purple", "red", "white", "yellow"
]дддюжї

def find_color_files(base_dir: Path) -> List[Path]:
    """Find all color files in all style directories."""
    color_files = []
    
    # Look in all style directories
    for style_dir in base_dir.iterdir():
        if style_dir.is_dir() and style_dir.name != "generated":
            for file_path in style_dir.glob("*.png"):
                # Check if file ends with any color name
                stem = file_path.stem  # filename without extension
                for color in COLOR_NAMES:
                    if stem.endswith(f"_{color}"):
                        color_files.append(file_path)
                        break
    
    return color_files

def move_color_files(base_dir: Path, archive_dir: Path, dry_run: bool = False):
    """Move all color files to archive directory, organized by original style."""
    color_files = find_color_files(base_dir)
    
    print(f"Found {len(color_files)} color files to move")
    
    if dry_run:
        print("DRY RUN - No files will be moved")
    else:
        # Create archive directory if it doesn't exist
        archive_dir.mkdir(parents=True, exist_ok=True)
    
    moved_count = 0
    for file_path in color_files:
        # Get the style directory name (parent directory)
        style_name = file_path.parent.name
        
        # Create style subdirectory in archive
        style_archive_dir = archive_dir / style_name
        if not dry_run:
            style_archive_dir.mkdir(exist_ok=True)
        
        # Move file to archive
        destination = style_archive_dir / file_path.name
        action = "Would move" if dry_run else "Moving"
        print(f"{action} {file_path.relative_to(base_dir)} -> {destination.relative_to(base_dir.parent)}")
        
        if not dry_run:
            shutil.move(str(file_path), str(destination))
        moved_count += 1
    
    action = "Would move" if dry_run else "Successfully moved"
    print(f"{action} {moved_count} color files to archive")

def main():
    parser = argparse.ArgumentParser(description="Move color files from flashcard image directories to archive")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be moved without actually moving files")
    parser.add_argument("--force", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args()
    
    # Define paths
    base_dir = Path(__file__).parent.parent / "BabyKeyboardLock" / "Resources" / "FlashcardImages"
    archive_dir = base_dir.parent / "ArchivedColorImages"
    
    print(f"Base directory: {base_dir}")
    print(f"Archive directory: {archive_dir}")
    
    if not base_dir.exists():
        print(f"Error: Base directory {base_dir} does not exist")
        return
    
    # Preview what will be moved
    color_files = find_color_files(base_dir)
    print(f"\nPreview: Found {len(color_files)} color files:")
    for file_path in sorted(color_files)[:10]:  # Show first 10 as preview
        print(f"  {file_path.relative_to(base_dir)}")
    if len(color_files) > 10:
        print(f"  ... and {len(color_files) - 10} more")
    
    # Ask for confirmation unless force flag is used or it's a dry run
    if args.dry_run or args.force:
        move_color_files(base_dir, archive_dir, dry_run=args.dry_run)
    else:
        try:
            response = input(f"\nProceed to move {len(color_files)} files to {archive_dir}? (y/N): ")
            if response.lower() in ['y', 'yes']:
                move_color_files(base_dir, archive_dir)
            else:
                print("Operation cancelled")
        except (EOFError, KeyboardInterrupt):
            print("\nOperation cancelled")

if __name__ == "__main__":
    main()
