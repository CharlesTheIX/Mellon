"""
Builder Utilities - Build operations and platform-specific logic.
"""

import os
import subprocess
from utils.system import SystemUtils


class Builder:
    """Handles building for different platforms and optimization levels."""
    
    @staticmethod
    def build(build_type=None, optimize_flag=None):
        """
        Build the Zig project with specified options.
        
        Args:
            build_type (str): 'macos', 'windows', or None
            optimize_flag (str): 'safe', 'fast', 'small', or None
        
        Raises:
            subprocess.CalledProcessError: If build fails
        """
        if build_type == "windows":
            Builder._build_windows(optimize_flag)
        else:
            Builder._build_default(build_type, optimize_flag)
    
    @staticmethod
    def _build_default(build_type, optimize_flag):
        """Build for default target."""
        cmd = ["zig", "build"]
        
        if optimize_flag and optimize_flag != "default":
            optimize_map = {
                "safe": "ReleaseSafe",
                "fast": "ReleaseFast",
                "small": "ReleaseSmall",
            }
            opt_value = optimize_map.get(optimize_flag, optimize_flag)
            cmd.append(f"-Doptimize={opt_value}")
        
        print(f"Running: {' '.join(cmd)}")
        SystemUtils.run_command(cmd, check=True)
    
    @staticmethod
    def _build_windows(optimize_flag):
        """Build for Windows target."""
        cmd = ["zig", "build", "-Dtarget=x86_64-windows"]
        
        if optimize_flag:
            optimize_map = {
                "safe": "ReleaseSafe",
                "fast": "ReleaseFast",
                "small": "ReleaseSmall",
            }
            opt_value = optimize_map.get(optimize_flag, optimize_flag)
            cmd.append(f"-Doptimize={opt_value}")
        
        print(f"Running: {' '.join(cmd)}")
        SystemUtils.run_command(cmd, check=True)
    
    @staticmethod
    def get_bundle_size(build_type):
        """
        Get the size of the built bundle.
        
        Args:
            build_type (str): Type of bundle ('macos', 'windows', or None)
        
        Returns:
            str: Human-readable size string
        """
        if build_type == "macos":
            if os.path.isdir("Mellon.app"):
                result = subprocess.run(
                    ["du", "-sh", "Mellon.app"],
                    capture_output=True,
                    text=True
                )
                return result.stdout.split()[0]
            else:
                return "Mellon.app not found"
        
        elif build_type == "windows":
            if os.path.exists("Mellon/Mellon.exe"):
                result = subprocess.run(
                    ["du", "-h", "Mellon/Mellon.exe"],
                    capture_output=True,
                    text=True
                )
                return result.stdout.split()[0]
            else:
                return "Mellon.exe not found"
        
        else:
            if os.path.exists("zig-out/bin/mellon"):
                result = subprocess.run(
                    ["du", "-h", "zig-out/bin/mellon"],
                    capture_output=True,
                    text=True
                )
                return result.stdout.split()[0]
            else:
                return "mellon binary not found"
