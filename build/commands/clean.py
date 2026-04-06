"""
Clean Command - Removes build artifacts.
"""

import os
import shutil
from utils.args import parse_args
from commands.base import Command


class CleanCommand(Command):
    """Handle cleaning build artifacts."""
    
    CLEAN_DIRS = [".data", "Mellon", "zig-out", "Mellon.app", ".zig-cache"]
    
    def execute(self, args):
        """Remove all build artifacts."""
        _ = parse_args(args) # Currently no specific arguments for clean command
        print("Cleaning build artifacts...")
        for directory in self.CLEAN_DIRS:
            if os.path.exists(directory):
                if os.path.isfile(directory):
                    os.remove(directory)
                    print(f"  Removed file: {directory}")
                else:
                    shutil.rmtree(directory)
                    print(f"  Removed directory: {directory}")
        print("✅ Clean complete.")
