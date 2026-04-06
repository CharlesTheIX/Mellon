"""
Run Command - Executes the Mellon application.
"""

import os
import platform
import subprocess
from utils.args import parse_args
from commands.base import Command


class RunCommand(Command):
    """Handle running the Mellon application."""
    
    def execute(self, args):
        """
        Execute the application based on the current OS.
        
        Args:
            args (list): Unused
        """
        _ = parse_args(args) # Currently no specific arguments for run command
        system = platform.system()
        if system == "Darwin":
            self._run_macos()
        elif system == "Linux":
            self._run_linux()
        elif system in ("Windows", "MINGW64", "MSYS", "CYGWIN"):
            self._run_windows()
        else:
            raise RuntimeError(f"Unsupported OS: {system}")
    
    @staticmethod
    def _run_macos():
        """Run on macOS."""
        print("Running Mellon on macOS...")
        binary = "./zig-out/bin/mellon"
        if not os.path.exists(binary):
            raise FileNotFoundError(f"Binary not found: {binary}")
        subprocess.run([binary])
    
    @staticmethod
    def _run_linux():
        """Run on Linux."""
        print("Running Mellon on Linux...")
        binary = "./zig-out/bin/mellon"
        if not os.path.exists(binary):
            raise FileNotFoundError(f"Binary not found: {binary}")
        subprocess.run([binary])
    
    @staticmethod
    def _run_windows():
        """Run on Windows."""
        print("Running Mellon on Windows...")
        binary = "./zig-out/bin/mellon.exe"
        if not os.path.exists(binary):
            raise FileNotFoundError(f"Binary not found: {binary}")
        subprocess.run([binary])
