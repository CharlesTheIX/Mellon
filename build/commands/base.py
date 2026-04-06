"""
Base Command class - Abstract base for all commands.
"""

from abc import ABC, abstractmethod


class Command(ABC):
    """Abstract base class for all commands."""
    
    @abstractmethod
    def execute(self, args):
        """
        Execute the command with given arguments.
        
        Args:
            args (list): Command arguments
        """
        pass
