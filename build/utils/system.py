"""
System Utilities - System checks and OS-specific operations.
"""

import sys
import subprocess


class SystemUtils:
    """Utility functions for system operations."""
    
    @staticmethod
    def run_command(cmd, check=True, capture=False):
        """
        Run a shell command.
        
        Args:
            cmd (list): Command and arguments
            check (bool): Raise exception on error
            capture (bool): Capture output
        
        Returns:
            CompletedProcess: Command result
        
        Raises:
            subprocess.CalledProcessError: If check=True and command fails
        """
        kwargs = {
            "check": check,
        }
        
        if capture:
            kwargs["capture_output"] = True
            kwargs["text"] = True
        
        return subprocess.run(cmd, **kwargs)
