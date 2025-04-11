# StorageTool

A book storage management tool for Kindle devices.

StorageTool helps Kindle users analyze, visualize, and manage their ebook collections. It provides information about your book storage usage and helps you identify large files, duplicates, and organize your library.

![StorageTool Screenshot](screenshot.jpg)

## Features

- **Storage Overview**: See total, used, and free space on your Kindle
- **Book Collection Analysis**: Analyze books by file type (PDF, EPUB, MOBI, etc.)
- **Large Book Scanner**: Find your largest books
- **Duplicate Finder**: Identify potential duplicate books based on filename
- **Recent Files Tracker**: See recently added or modified books
- **Customizable**: Configure your books directory path

## Requirements

- Kindle device
- KUAL (Kindle Unified Application Launcher)
- KTerm Extension for KUAL

## Installation

### Method 1: Install from USB

1. Connect your Kindle to your computer via USB
2. Copy the entire `storagetool` folder to the root of your Kindle
3. On your Kindle, use KUAL to navigate to the "Helper" section
4. Launch the "Terminal" or "KTerm" application
5. Run the following commands:
   ```
   cd /mnt/us/storagetool
   sh ./install.sh
   ```
6. Restart KUAL to see StorageTool in your menu

### Method 2: Direct Installation

1. Copy the `storagetool` folder to your Kindle's `/mnt/us/extensions/` directory
2. Make sure all scripts have executable permissions:
   ```
   chmod +x /mnt/us/extensions/storagetool/run.sh
   chmod +x /mnt/us/extensions/storagetool/bin/storagetool.sh
   ```
3. Restart KUAL to see StorageTool in your menu

## Usage

Launch StorageTool from the KUAL menu. From there, you can:

1. **Storage Overview**: View your Kindle's overall storage usage
2. **Scan Books Directory**: Analyze your books directory for size and file types
3. **Analyze by File Type**: See a breakdown of book formats and their storage usage
4. **Recent Files**: View recently added or modified books
5. **Find Duplicates**: Identify potential duplicate books
6. **Settings**: Configure StorageTool options and set your books directory

## Configuration

In the Settings menu, you can:
- Set your books directory (default: `/mnt/us/documents`)
- Toggle showing hidden files
- Enable/disable condensed output
- Enable/disable debug mode

## Credits

StorageTool was inspired by and built upon the framework of [KindleFetch](https://github.com/justrals/KindleFetch) by justrals. We thank the KindleFetch project for providing a solid foundation for Kindle extension development.

## License

This project is open source software, feel free to modify and distribute as needed.

## Troubleshooting

- If StorageTool doesn't appear in KUAL, make sure the extension is installed correctly and KUAL has been restarted
- If you encounter any "command not found" errors, check the file permissions of the scripts
- For any other issues, check the extension's installation and try reinstalling

## Version History

- **v2.0.0**: Initial public release with book management focus
- **v1.0.0**: Original development version based on KindleFetch
