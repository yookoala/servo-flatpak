# Servo Flatpak

This is a simple setup to download and build a Flatpak package for the latest Servo
testing binary.


## Prerequisites

You need these installed to build the Flatpak:
* `flatpak` - Flatpak runtime
* `flatpak-builder` - Tool to build Flatpak applications
* `curl` - For downloading from GitHub API
* `make` - For running the build automation
* Flathub repository configured (run: `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`)


## Usage

### Building the Flatpak

1. Generate the manifest file from the template (automatically fetches the latest Servo release):
   ```bash
   make
   ```

2. Build the Flatpak package:
   ```bash
   flatpak-builder --user --install --force-clean build-dir org.servo.Servo.yml
   ```

3. Run Servo:
   ```bash
   flatpak run org.servo.Servo
   ```

### Cleaning Up

To remove the generated manifest file:
```bash
make clean
```


## What It Does

The Makefile automatically:
- Fetches the latest Freedesktop Platform runtime version from Flathub
- Retrieves the latest Servo x86_64 Linux release URL from GitHub
- Downloads the SHA256 checksum for verification
- Generates `org.servo.Servo.yml` from the template with all the current versions


## Manual Build

If you prefer to build manually without the Makefile, edit `org.servo.Servo.yml.template` and replace the placeholders, then use `flatpak-builder` directly.


## License

This software is licensed under MIT License. A copy of the license can be found [here](LICENSE.md) in this
repository.