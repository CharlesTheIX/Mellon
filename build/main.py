#!/usr/bin/env python3
"""
Mellon Build Tool - Main Entry Point
A modular CLI tool for building, running, and managing the Mellon application.
"""

import sys
import time
from controller import Controller


def main():
    """Main entry point for the CLI tool."""
    start_time = time.time()
    
    if len(sys.argv) < 2:
        Controller.show_help()
        sys.exit(0)
    
    command = sys.argv[1]
    args = sys.argv[2:]
    
    try:
        controller = Controller()
        controller.handle_command(command, args)
    except KeyboardInterrupt:
        print("\n\nAborted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        elapsed = int(time.time() - start_time)
        print(f"Command '{command}' completed in {elapsed} seconds.")


if __name__ == "__main__":
    main()
