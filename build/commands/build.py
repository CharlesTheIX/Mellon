"""
Build Command - Handles building the Mellon application.
"""

import os
import shutil
import tempfile
from utils.args import parse_args
from commands.base import Command
from utils.builders import Builder
from utils.system import SystemUtils
from utils.data_prep import DataPreparation


class BuildCommand(Command):
    """Handle application builds for different platforms."""

    MACOS_ICON_NAME = "AppIcon.icns"
    MACOS_ICONSET_FILES = (
        "icon_16x16.png",
        "icon_16x16@2x.png",
        "icon_32x32.png",
        "icon_32x32@2x.png",
        "icon_128x128.png",
        "icon_128x128@2x.png",
        "icon_256x256.png",
        "icon_256x256@2x.png",
        "icon_512x512.png",
        "icon_512x512@2x.png",
    )
    
    def execute(self, args):
        """
        Execute the build command.
        
        Args:
            args (list): Named arguments in format ["os=macos", "optimize=fast", "audio=wav"]
                os: 'macos', 'windows', or None (default build)
                optimize: 'safe', 'fast', 'small', or None (default: none)
        """
        parsed = parse_args(args)
        build_type = parsed.get('os')
        optimize_flag = parsed.get('optimize')
        print(f"Building application with type: {build_type or 'default'}...")
        
        # Prepare data files
        try:
            DataPreparation.prepare_all_data()
        except Exception as e:
            print(f"Data preparation failed: {e}")
            raise
        
        builder = Builder()
        builder.build(build_type, optimize_flag)
        if build_type == 'macos':
            self._create_macos_bundle()
        elif build_type == 'windows':
            self._create_windows_bundle()
        
        bundle_size = builder.get_bundle_size(build_type)
        print(f"Bundle size: {bundle_size}")
    
    def _create_macos_bundle(self):
        """Create macOS app bundle."""
        print("Creating Mellon.app bundle...")
        
        if os.path.exists("Mellon.app"):
            shutil.rmtree("Mellon.app")
        
        os.makedirs("Mellon.app/Contents/MacOS", exist_ok=True)
        os.makedirs("Mellon.app/Contents/Resources", exist_ok=True)
        if os.path.exists("zig-out/bin/mellon"):
            shutil.copy("zig-out/bin/mellon", "Mellon.app/Contents/MacOS/")
        else:
            raise FileNotFoundError("Build output not found at zig-out/bin/mellon")

        self._add_macos_icon()
        self._write_macos_plist()
        
        print("✅ macOS app bundle created: Mellon.app")

    def _add_macos_icon(self):
        """Generate AppIcon.icns from the bundled PNG icon set."""
        iconutil_path = shutil.which("iconutil")
        if not iconutil_path:
            raise RuntimeError("macOS packaging requires 'iconutil' to generate AppIcon.icns")

        assets_dir = os.path.join("build", "assets", "images")
        missing_files = [
            file_name
            for file_name in self.MACOS_ICONSET_FILES
            if not os.path.exists(os.path.join(assets_dir, file_name))
        ]
        if missing_files:
            raise FileNotFoundError(
                "Missing required macOS icon assets in build/assets/images: "
                + ", ".join(missing_files)
            )

        output_path = os.path.join("Mellon.app", "Contents", "Resources", self.MACOS_ICON_NAME)
        with tempfile.TemporaryDirectory() as temp_dir:
            iconset_dir = os.path.join(temp_dir, "AppIcon.iconset")
            os.makedirs(iconset_dir, exist_ok=True)

            for file_name in self.MACOS_ICONSET_FILES:
                shutil.copy(
                    os.path.join(assets_dir, file_name),
                    os.path.join(iconset_dir, file_name),
                )

            SystemUtils.run_command(
                [iconutil_path, "--convert", "icns", iconset_dir, "--output", output_path],
                check=True,
            )
    
    def _create_windows_bundle(self):
        """Create Windows distribution package."""
        print("Creating Windows distribution package...")
        
        if os.path.exists("Mellon"):
            shutil.rmtree("Mellon")
        
        os.makedirs("Mellon", exist_ok=True)
        if os.path.exists("zig-out/bin/mellon.exe"):
            shutil.copy("zig-out/bin/mellon.exe", "Mellon/Mellon.exe")
            print("✅ Mellon/Mellon.exe created successfully!")
            print("Package contents:")
            for item in os.listdir("Mellon"):
                path = os.path.join("Mellon", item)
                size = os.path.getsize(path)
                print(f"  {item:<30} {size:>10} bytes")
        else:
            raise FileNotFoundError(
                "Build output not found at zig-out/bin/mellon.exe. "
                "Build for Windows target first: zig build -Dtarget=x86_64-windows"
            )
    
    @staticmethod
    def _write_macos_plist():
        """Write macOS Info.plist file."""
        plist_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>mellon</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.mellon</string>
    <key>CFBundleName</key>
    <string>Mellon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
"""
        plist_path = "Mellon.app/Contents/Info.plist"
        with open(plist_path, "w") as f:
            f.write(plist_content)
