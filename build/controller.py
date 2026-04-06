"""
Controller Module - Routes commands to appropriate handlers.
"""

from commands.run import RunCommand
from commands.build import BuildCommand
from commands.clean import CleanCommand


class Controller:
    """Main controller that routes CLI commands to appropriate modules."""
    
    def __init__(self):
        """Initialize the controller with available commands."""
        self.commands = {
            'run': RunCommand(),
            'build': BuildCommand(),
            'clean': CleanCommand(),
            'help': None,  # Special case handled separately
        }
    
    def handle_command(self, command, args):
        """
        Route command to appropriate handler.
        
        Args:
            command (str): The command name
            args (list): Arguments to pass to the command
        """
        if command == 'help':
            self.show_help()
            return
        
        if command not in self.commands:
            print(f"Unknown command: {command}")
            print()
            self.show_help()
            raise SystemExit(1)
        
        handler = self.commands[command]
        if handler:
            handler.execute(args)
    
    @staticmethod
    def show_help():
        """Display help message for all available commands."""
        help_text = """
Mellon Build Tool

Usage: ./main.py <command> [options]

Available commands:
  build [options]           Build the application.
    Options (all optional, key=value format):
      os=macos|windows      Operating system target (default: standard build)
      optimize=safe|fast|small  Optimization level (default: none)
      audio=wav|ogg         Audio format (default: wav)
    Examples:
      ./main.py build                           # Standard build with WAV
      ./main.py build os=macos                  # macOS app bundle with AppIcon.icns
      ./main.py build os=macos optimize=fast    # macOS with fast optimization
      ./main.py build os=windows optimize=small # Windows with size optimization
      ./main.py build audio=ogg                 # Build with OGG audio
    Notes:
      macOS packaging expects PNG icon assets in build/assets/images
      and uses iconutil to generate Mellon.app/Contents/Resources/AppIcon.icns
  
  run                       Run the application
  
  clean                     Clean build artifacts
  
  audio [options]           Convert audio files.
    Options (optional, key=value format):
      format=wav|ogg        Audio format (default: wav)
    Examples:
      ./main.py audio                # Convert to WAV format
      ./main.py audio format=ogg      # Convert to OGG format
  
  help                      Show this help message
"""
        print(help_text)
