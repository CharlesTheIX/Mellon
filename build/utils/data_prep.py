"""
Data Preparation - Handles copying and preparing data files for build.
"""

import os
import json
import shutil


class DataPreparation:
    """Utility for preparing data files from build/data to .data/."""
    
    TARGET_DATA_DIR = ".data"
    SOURCE_DATA_DIR = "build/data"
    SUB_DIRS = ["audio", "fonts", "maps"]
    
    @classmethod
    def prepare_all_data(cls):
        """Prepare all data."""
        print("Preparing data files...")
    #    Prep here 
        print("✅ Data preparation complete.")

    @classmethod
    def clean_target_data(cls):
        """Remove the target data directory."""
        if os.path.exists(cls.TARGET_DATA_DIR):
            # Remove only our managed subdirectories
            for subdir in SUB_DIRS:
                target = os.path.join(cls.TARGET_DATA_DIR, subdir)
                if os.path.exists(target):
                    shutil.rmtree(target)
                    print(f"  Removed {target}")
