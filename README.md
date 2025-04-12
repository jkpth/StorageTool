# StorageTool

Storage management tool for jailbroken Kindle devices.

StorageTool helps Kindle users analyze, visualize, and manage their ebook collections. It provides information about your book storage usage and helps you identify large files, duplicates, and organize your library.

## Requirements

**Your Kindle must be jailbroken before proceeding!**  
If it's not, follow [this guide](https://kindlemodding.org/) first.

**Install kterm**:
1. Download the latest release from [kterm's releases page](https://github.com/bfabiszewski/kterm/releases)
2. Unzip the archive to the `extensions` directory in your Kindle's root

**KOReader (Optional but Recommended):**

1. **Download** the latest release from the [KOReader Releases Page](https://github.com/koreader/koreader/releases)
2. **Unsure which version to get?** Check the [Installation Guide](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices#err-there-are-four-kindle-packages-to-choose-from-which-do-i-pick)

## Installation

### Method 1: One-Line Install (Recommended)

1. On your Kindle, open KUAL and launch KTerm
2. Run the following command:
   ```
   curl https://jpt.bio/StorageTool/install.sh | sh
   ```
3. Restart KUAL to see StorageTool in your menu

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
7. **Check for Updates**: Automatically check for and install the latest version of StorageTool

## Configuration

In the Settings menu, you can:
- Set your books directory (default: `/mnt/us/documents`)
- Toggle showing hidden files
- Enable/disable condensed output
- Enable/disable debug mode

## Credits

Heavily inspired and built on top of [KindleFetch](https://github.com/justrals/KindleFetch) by justrals. 
Go check out this great project!

## License

This project is open source software, feel free to modify and distribute as needed.

## Troubleshooting

- If StorageTool doesn't appear in KUAL, make sure the extension is installed correctly and KUAL has been restarted
- If you encounter any "command not found" errors, check the file permissions of the scripts
- For any other issues, check the extension's installation and try reinstalling

## Version History

- **v2.0.1**: Added auto-update feature to check for and install the latest version
- **v2.0.0**: Initial public release with book management focus
- **v1.0.0**: Original development version based on KindleFetch
