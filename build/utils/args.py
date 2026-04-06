"""
Argument Parsing Utilities
"""


def parse_args(args):
    """
    Parse command-line arguments in key=value format.
    
    Args:
        args (list): List of arguments in format ["key1=value1", "key2=value2", ...]
    
    Returns:
        dict: Dictionary of parsed arguments
    
    Example:
        >>> parse_args(["os=macos", "optimize=fast"])
        {'os': 'macos', 'optimize': 'fast'}
    """
    parsed = {}
    for arg in args:
        if "=" in arg:
            key, value = arg.split("=", 1)
            parsed[key.strip()] = value.strip()
    return parsed
