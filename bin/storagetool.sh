#!/bin/sh

# StorageTool - Kindle Storage Analysis and Management Tool
# Based on KindleFetch's structure (https://github.com/justrals/KindleFetch)

# Variables
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$SCRIPT_DIR/.storagetool_config"
VERSION="1.0.0"

# Default directories to analyze
KINDLE_ROOT="/mnt/us"
DOCUMENTS_DIR="/mnt/us/documents"
TEMP_DIR="/tmp/storagetool"

# Color codes if supported
COLOR_SUPPORT=false
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Configuration options
SHOW_HIDDEN_FILES=false
CONDENSED_OUTPUT=false
DEBUG_MODE=false

# Temporary files
SCAN_RESULTS="$TEMP_DIR/scan_results.txt"
LARGE_FILES="$TEMP_DIR/large_files.txt"
RECENT_FILES="$TEMP_DIR/recent_files.txt"
TYPE_SUMMARY="$TEMP_DIR/type_summary.txt"
CURRENT_DIR_LISTING="$TEMP_DIR/current_dir.txt"
HISTORY_FILE="$TEMP_DIR/browse_history.txt"

# Check if running on a Kindle
is_kindle() {
    if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
        return 1
    fi
    return 0
}

# Initialize environment
init_environment() {
    if ! is_kindle; then
        echo "Warning: This script is designed to run on Kindle devices."
        echo "Some features may not work correctly on other systems."
        sleep 2
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Check for color support
    if [ -t 1 ] && command -v tput >/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
        COLOR_SUPPORT=true
    fi
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    else
        # Create default config
        save_config
    fi
}

# Save configuration
save_config() {
    echo "SHOW_HIDDEN_FILES=$SHOW_HIDDEN_FILES" > "$CONFIG_FILE"
    echo "CONDENSED_OUTPUT=$CONDENSED_OUTPUT" >> "$CONFIG_FILE"
    echo "DEBUG_MODE=$DEBUG_MODE" >> "$CONFIG_FILE"
}

# Print colored text if supported
print_colored() {
    if $COLOR_SUPPORT; then
        color_code="$1"
        shift
        echo -e "${color_code}$*${RESET}"
    else
        echo "$*"
    fi
}

# Format file size
format_size() {
    size="$1"
    if [ "$size" -gt 1073741824 ]; then # 1GB
        echo "$(echo "scale=2; $size / 1073741824" | bc)G"
    elif [ "$size" -gt 1048576 ]; then # 1MB
        echo "$(echo "scale=2; $size / 1048576" | bc)M"
    elif [ "$size" -gt 1024 ]; then # 1KB
        echo "$(echo "scale=2; $size / 1024" | bc)K"
    else
        echo "${size}B"
    fi
}

# Generate ASCII bar chart
generate_bar_chart() {
    total=$1
    value=$2
    width=40
    filled=$(echo "scale=0; $width * $value / $total" | bc)
    
    bar=""
    i=0
    while [ "$i" -lt "$width" ]; do
        if [ "$i" -lt "$filled" ]; then
            bar="${bar}#"
        else
            bar="${bar}-"
        fi
        i=$((i+1))
    done
    
    percent=$(echo "scale=1; 100 * $value / $total" | bc)
    echo "$bar ($percent%)"
}

# Clean up temporary files
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

# ----------------------------------
# Storage Analysis Functions
# ----------------------------------

# Get disk usage information
get_disk_info() {
    clear
    print_colored "$CYAN" "
  _____ _                              _____        __      
 / ____| |                            |_   _|      / _|     
| (___ | |_ ___  _ __ __ _  __ _  ___   | |  _ __ | |_ ___  
 \___ \| __/ _ \| '__/ _\` |/ _\` |/ _ \  | | | '_ \|  _/ _ \ 
 ____) | || (_) | | | (_| | (_| |  __/ _| |_| | | | || (_) |
|_____/ \__\___/|_|  \__,_|\__, |\___||_____|_| |_|_| \___/ 
                            __/ |                            
                           |___/                             
"
    print_colored "$GREEN" "Analyzing disk space usage..."
    echo ""
    
    # Overall disk space
    df_out=$(df -h /mnt/us 2>/dev/null)
    total_size=$(echo "$df_out" | awk 'NR==2 {print $2}')
    used_size=$(echo "$df_out" | awk 'NR==2 {print $3}')
    free_size=$(echo "$df_out" | awk 'NR==2 {print $4}')
    used_percent=$(echo "$df_out" | awk 'NR==2 {print $5}' | tr -d '%')
    
    echo "Total storage: $total_size"
    echo "Used storage:  $used_size ($used_percent%)"
    echo "Free storage:  $free_size"
    
    # Create visual representation
    echo ""
    echo "Storage usage:"
    generate_bar_chart 100 "$used_percent"
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Scan for large files
scan_large_files() {
    clear
    print_colored "$CYAN" "
 _                         _______ _           
| |                       |__   __(_)          
| |     __ _ _ __ __ _  ___  | |   _ _ __ ___  
| |    / _\` | '__/ _\` |/ _ \ | |  | | '_ \` _ \ 
| |___| (_| | | | (_| |  __/ | |  | | | | | | |
|______\__,_|_|  \__, |\___| |_|  |_|_| |_| |_|
                  __/ |                        
                 |___/                         
"
    print_colored "$GREEN" "Scanning for large files (this may take a while)..."
    echo ""
    
    # Finding largest files
    echo "Top 20 largest files:"
    echo ""
    find "$KINDLE_ROOT" -type f -size +1M 2>/dev/null | xargs ls -lh 2>/dev/null | sort -rh -k5 | head -20 | 
        awk '{printf("%2d. %s (%s)\n", NR, $9, $5)}' | tee "$LARGE_FILES"
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Analyze storage by file type
analyze_by_type() {
    clear
    print_colored "$CYAN" "
 ______ _ _      _______                  
|  ____(_) |    |__   __|                 
| |__   _| | ___   | |_   _ _ __   ___  ___
|  __| | | |/ _ \  | | | | | '_ \ / _ \/ __|
| |    | | |  __/  | | |_| | |_) |  __/\__ \\
|_|    |_|_|\___|  |_|\__, | .__/ \___||___/
                        __/ | |              
                       |___/|_|              
"
    print_colored "$GREEN" "Analyzing storage by file type..."
    echo ""
    
    # Define common file extensions and their descriptions
    echo "Collecting data on file types..."
    
    > "$TYPE_SUMMARY"
    
    # E-books
    find "$KINDLE_ROOT" -type f -name "*.azw" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.kfx" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "E-books:", $1)}' >> "$TYPE_SUMMARY"
    
    # PDFs
    find "$KINDLE_ROOT" -type f -name "*.pdf" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "PDFs:", $1)}' >> "$TYPE_SUMMARY"
    
    # Documents
    find "$KINDLE_ROOT" -type f -name "*.doc" -o -name "*.docx" -o -name "*.txt" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "Documents:", $1)}' >> "$TYPE_SUMMARY"
    
    # Images
    find "$KINDLE_ROOT" -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "Images:", $1)}' >> "$TYPE_SUMMARY"
    
    # Audio
    find "$KINDLE_ROOT" -type f -name "*.mp3" -o -name "*.aac" -o -name "*.wav" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "Audio:", $1)}' >> "$TYPE_SUMMARY"
    
    # System files
    find "$KINDLE_ROOT" -type f -name "*.json" -o -name "*.xml" -o -name "*.html" -o -name "*.js" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "System files:", $1)}' >> "$TYPE_SUMMARY"
    
    # Now calculate sizes
    echo "Calculating sizes for each type (this may take a while)..."
    
    # E-books size
    ebook_size=$(find "$KINDLE_ROOT" -type f -name "*.azw" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.kfx" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$ebook_size" ] && ebook_size=0
    
    # PDFs size
    pdf_size=$(find "$KINDLE_ROOT" -type f -name "*.pdf" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$pdf_size" ] && pdf_size=0
    
    # Documents size
    doc_size=$(find "$KINDLE_ROOT" -type f -name "*.doc" -o -name "*.docx" -o -name "*.txt" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$doc_size" ] && doc_size=0
    
    # Images size
    img_size=$(find "$KINDLE_ROOT" -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$img_size" ] && img_size=0
    
    # Calculate total content size for percentage
    total_analyzed=$((ebook_size + pdf_size + doc_size + img_size))
    [ "$total_analyzed" -eq 0 ] && total_analyzed=1  # Prevent division by zero
    
    clear
    print_colored "$CYAN" "File Type Analysis"
    echo "--------------------"
    cat "$TYPE_SUMMARY"
    echo ""
    
    echo "Storage Usage by Type:"
    echo "E-books:    $(format_size "$ebook_size")"
    generate_bar_chart "$total_analyzed" "$ebook_size"
    
    echo "PDFs:       $(format_size "$pdf_size")"
    generate_bar_chart "$total_analyzed" "$pdf_size"
    
    echo "Documents:  $(format_size "$doc_size")"
    generate_bar_chart "$total_analyzed" "$doc_size"
    
    echo "Images:     $(format_size "$img_size")"
    generate_bar_chart "$total_analyzed" "$img_size"
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Scan for recent files
scan_recent_files() {
    clear
    print_colored "$CYAN" "
______                      _   
| ___ \                    | |  
| |_/ /___  ___ ___ _ __ | |_ 
|    // _ \/ __/ _ \ '_ \| __|
| |\ \  __/ (_|  __/ | | | |_ 
\_| \_\___|\___\___|_| |_|\__|
                             
"
    print_colored "$GREEN" "Analyzing recently added files..."
    echo ""
    
    # Find files modified in the last 30 days
    echo "Files added/modified in the last 30 days (largest first):"
    echo ""
    find "$KINDLE_ROOT" -type f -mtime -30 2>/dev/null | xargs ls -lh 2>/dev/null | sort -rh -k5 | head -15 |
        awk '{printf("%2d. %s (%s)\n", NR, $9, $5)}' | tee "$RECENT_FILES"
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Find duplicate files (basic implementation - can be expanded)
find_duplicates() {
    clear
    print_colored "$CYAN" "
______            _ _           _            
|  _  \          | (_)         | |           
| | | |_   _ _ __| |_  ___ __ _| |_ ___  ___ 
| | | | | | | '__| | |/ __/ _\` | __/ _ \/ __|
| |/ /| |_| | |  | | | (_| (_| | ||  __/\__ \\
|___/  \__,_|_|  |_|_|\___\__,_|\__\___||___/
                                             
"
    print_colored "$GREEN" "Scanning for duplicate files (based on name)..."
    echo ""
    
    # This is a simple duplicate finder based on filenames
    # A more thorough approach would compare file checksums, but that's resource-intensive
    
    echo "Looking for duplicate files..."
    find "$DOCUMENTS_DIR" -type f -name "*.pdf" -o -name "*.mobi" -o -name "*.azw" -o -name "*.azw3" 2>/dev/null | 
        awk -F "/" '{print $NF}' | sort | uniq -d | head -20 > "$TEMP_DIR/dupes.txt"
    
    if [ -s "$TEMP_DIR/dupes.txt" ]; then
        echo "Potential duplicate files found (based on filename):"
        echo ""
        cat "$TEMP_DIR/dupes.txt" | nl
        echo ""
        echo "Note: This only checks for identical filenames, not content."
    else
        echo "No duplicate filenames found in the documents directory."
    fi
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# File browser
browse_directory() {
    current_dir="$KINDLE_ROOT"
    # Initialize empty history file
    : > "$HISTORY_FILE"
    
    while true; do
        clear
        print_colored "$CYAN" "
 _______ _      ______                                
|__   __(_)    |  ____|                               
   | |   _  ___| |__   _ __ _____      _____  ___ _ __ 
   | |  | |/ _ \  __| | '__/ _ \ \ /\ / / __|/ _ \ '__|
   | |  | |  __/ |____| | | (_) \ V  V /\__ \  __/ |   
   |_|  |_|\___|______|_|  \___/ \_/\_/ |___/\___|_|   
                                                                         
"
        echo "Current directory: $current_dir"
        echo "------------------------------------------------"
        
        # List files and directories with sizes
        find "$current_dir" -maxdepth 1 -mindepth 1 2>/dev/null | sort | while read -r item; do
            if [ -d "$item" ]; then
                dir_size=$(du -sh "$item" 2>/dev/null | cut -f1)
                base_name=$(basename "$item")
                echo "📁 [DIR] $base_name ($dir_size)"
            elif [ -f "$item" ]; then
                file_size=$(du -h "$item" 2>/dev/null | cut -f1)
                base_name=$(basename "$item")
                
                # Determine file type emoji based on extension
                ext=$(echo "$base_name" | awk -F. '{if (NF>1) print $NF}')
                case "$ext" in
                    pdf)
                        emoji="📄"
                        ;;
                    azw|azw3|mobi|kfx)
                        emoji="📚"
                        ;;
                    jpg|jpeg|png|gif)
                        emoji="🖼️"
                        ;;
                    mp3|aac|wav)
                        emoji="🎵"
                        ;;
                    *)
                        emoji="📄"
                        ;;
                esac
                
                echo "$emoji [FILE] $base_name ($file_size)"
            fi
        done > "$CURRENT_DIR_LISTING"
        
        # Handle pagination if the list is too long
        total_lines=$(wc -l < "$CURRENT_DIR_LISTING")
        max_display=15
        
        if [ "$total_lines" -gt "$max_display" ]; then
            # Simple pagination
            head -n "$max_display" "$CURRENT_DIR_LISTING"
            echo "... and $((total_lines - max_display)) more items (navigate to see more)"
        else
            cat "$CURRENT_DIR_LISTING"
        fi
        
        echo ""
        echo "Commands:"
        echo "Enter directory name to browse"
        echo "d [name]: Delete file/directory"
        echo "s [name]: Show file details"
        echo "u: Go up one directory"
        echo "b: Go back to previous directory"
        echo "q: Return to main menu"
        echo ""
        echo -n "Enter command: "
        read command arg
        
        case "$command" in
            d)
                if [ -z "$arg" ]; then
                    echo "Error: Missing file/directory name"
                    sleep 1
                    continue
                fi
                
                target="$current_dir/$arg"
                
                if [ -f "$target" ]; then
                    echo "Delete file: $arg?"
                    echo -n "Are you sure? (y/n): "
                    read confirm
                    
                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        rm "$target" 2>/dev/null
                        echo "File deleted."
                    else
                        echo "Operation cancelled."
                    fi
                elif [ -d "$target" ]; then
                    echo "Delete directory: $arg and all its contents?"
                    echo -n "Are you sure? This cannot be undone! (y/n): "
                    read confirm
                    
                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        rm -rf "$target" 2>/dev/null
                        echo "Directory deleted."
                    else
                        echo "Operation cancelled."
                    fi
                else
                    echo "File or directory not found: $arg"
                fi
                
                sleep 1
                ;;
            s)
                if [ -z "$arg" ]; then
                    echo "Error: Missing file name"
                    sleep 1
                    continue
                fi
                
                target="$current_dir/$arg"
                
                if [ -f "$target" ]; then
                    clear
                    echo "File details for: $arg"
                    echo "----------------------"
                    echo "Size: $(du -h "$target" 2>/dev/null | cut -f1)"
                    echo "Type: $(file -b "$target" 2>/dev/null || echo "Unknown")"
                    echo "Modified: $(date -r "$target" 2>/dev/null)"
                    echo ""
                    echo "Press any key to continue..."
                    read -n 1 -s
                else
                    echo "File not found: $arg"
                    sleep 1
                fi
                ;;
            u)
                # Go up one directory level
                parent=$(dirname "$current_dir")
                if [ "$parent" != "$current_dir" ]; then
                    # Add to history
                    echo "$current_dir" >> "$HISTORY_FILE"
                    current_dir="$parent"
                fi
                ;;
            b)
                # Go back to previous directory in history
                if [ -s "$HISTORY_FILE" ]; then
                    prev_dir=$(tail -1 "$HISTORY_FILE")
                    sed -i '$d' "$HISTORY_FILE" 2>/dev/null || { head -n -1 "$HISTORY_FILE" > "$HISTORY_FILE.new"; mv "$HISTORY_FILE.new" "$HISTORY_FILE"; }
                    current_dir="$prev_dir"
                fi
                ;;
            q)
                # Quit to main menu
                return
                ;;
            *)
                # Assume user wants to navigate to a directory
                target="$current_dir/$command"
                if [ -d "$target" ]; then
                    # Add current dir to history
                    echo "$current_dir" >> "$HISTORY_FILE"
                    current_dir="$target"
                else
                    echo "Invalid command or directory not found."
                    sleep 1
                fi
                ;;
        esac
    done
}

# Cleanup utility for temporary files
cleanup_utility() {
    clear
    print_colored "$CYAN" "
  _____ _                                
 / ____| |                               
| |    | | ___  __ _ _ __  _   _ _ __   
| |    | |/ _ \/ _\` | '_ \| | | | '_ \  
| |____| |  __/ (_| | | | | |_| | |_) | 
 \_____|_|\___|\__,_|_| |_|\__,_| .__/  
                               | |     
                               |_|     
"
    print_colored "$GREEN" "Cleanup Utility"
    echo "---------------------"
    echo ""
    
    echo "Select cleanup option:"
    echo "1. Clear browser cache"
    echo "2. Remove temporary files"
    echo "3. Clean log files"
    echo "4. Full system cleanup (all of the above)"
    echo "5. Back to main menu"
    echo ""
    echo -n "Select option: "
    read option
    
    case "$option" in
        1)
            clear_browser_cache
            ;;
        2)
            clear_temp_files
            ;;
        3)
            clear_log_files
            ;;
        4)
            clear_browser_cache
            clear_temp_files
            clear_log_files
            echo ""
            echo "Full system cleanup completed."
            ;;
        5)
            return
            ;;
        *)
            echo "Invalid option."
            sleep 1
            ;;
    esac
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Clear browser cache
clear_browser_cache() {
    echo "Clearing browser cache..."
    
    # Common browser cache directories on Kindle
    echo "$KINDLE_ROOT/browser/cache" > "$TEMP_DIR/cache_dirs.txt"
    echo "$KINDLE_ROOT/system/browser/cache" >> "$TEMP_DIR/cache_dirs.txt"
    
    space_before=0
    
    # Calculate space used before cleaning
    while read -r dir; do
        if [ -d "$dir" ]; then
            size=$(du -sk "$dir" 2>/dev/null | cut -f1)
            space_before=$((space_before + size))
        fi
    done < "$TEMP_DIR/cache_dirs.txt"
    
    # Clear each cache directory
    while read -r dir; do
        if [ -d "$dir" ]; then
            # Create temporary directory to keep the structure but delete contents
            rm -rf "${dir:?}/"* 2>/dev/null
            echo "- Cleared $dir"
        fi
    done < "$TEMP_DIR/cache_dirs.txt"
    
    # Calculate space freed
    space_after=0
    while read -r dir; do
        if [ -d "$dir" ]; then
            size=$(du -sk "$dir" 2>/dev/null | cut -f1)
            space_after=$((space_after + size))
        fi
    done < "$TEMP_DIR/cache_dirs.txt"
    
    space_freed=$((space_before - space_after))
    echo "Browser cache cleared. $(format_size $((space_freed * 1024))) freed."
}

# Clear temporary files
clear_temp_files() {
    echo "Removing temporary files..."
    
    # Common temporary directories on Kindle
    echo "/tmp" > "$TEMP_DIR/temp_dirs.txt"
    echo "$KINDLE_ROOT/system/tmp" >> "$TEMP_DIR/temp_dirs.txt"
    
    space_before=0
    
    # Calculate space used before cleaning
    while read -r dir; do
        if [ -d "$dir" ]; then
            size=$(du -sk "$dir" 2>/dev/null | cut -f1)
            space_before=$((space_before + size))
        fi
    done < "$TEMP_DIR/temp_dirs.txt"
    
    # Clean each temp directory
    while read -r dir; do
        if [ -d "$dir" ]; then
            # Skip current script's temp folder
            find "$dir" -mindepth 1 -not -path "$TEMP_DIR*" -delete 2>/dev/null
            echo "- Cleaned $dir"
        fi
    done < "$TEMP_DIR/temp_dirs.txt"
    
    # Calculate space freed
    space_after=0
    while read -r dir; do
        if [ -d "$dir" ]; then
            size=$(du -sk "$dir" 2>/dev/null | cut -f1)
            space_after=$((space_after + size))
        fi
    done < "$TEMP_DIR/temp_dirs.txt"
    
    space_freed=$((space_before - space_after))
    echo "Temporary files removed. $(format_size $((space_freed * 1024))) freed."
}

# Clear log files
clear_log_files() {
    echo "Cleaning log files..."
    
    # Find and count log files
    find "$KINDLE_ROOT" -name "*.log" -type f 2>/dev/null > "$TEMP_DIR/log_files.txt"
    log_count=$(wc -l < "$TEMP_DIR/log_files.txt")
    
    if [ "$log_count" -gt 0 ]; then
        # Calculate space before deletion
        space_before=0
        while read -r log; do
            size=$(du -sk "$log" 2>/dev/null | cut -f1)
            space_before=$((space_before + size))
        done < "$TEMP_DIR/log_files.txt"
        
        # Empty log files but don't delete them (some applications need the files to exist)
        while read -r log; do
            : > "$log" 2>/dev/null
        done < "$TEMP_DIR/log_files.txt"
        
        # Report results
        echo "Emptied $log_count log files. $(format_size $((space_before * 1024))) freed."
    else
        echo "No log files found."
    fi
}

# Export storage report
export_storage_report() {
    clear
    print_colored "$CYAN" "
 _____                       _   
|  ___|                     | |  
| |____  ___ __   ___  _ __| |_ 
|  __\ \/ / '_ \ / _ \| '__| __|
| |___>  <| |_) | (_) | |  | |_ 
\____/_/\_\ .__/ \___/|_|   \__|
          | |                    
          |_|                    
"
    echo "Generating storage report..."
    echo ""
    
    report_file="$KINDLE_ROOT/documents/StorageTool_Report_$(date +%Y%m%d).txt"
    
    {
        echo "====================================="
        echo "StorageTool Storage Report"
        echo "Generated: $(date)"
        echo "====================================="
        echo ""
        
        # Overall storage
        echo "STORAGE OVERVIEW"
        echo "----------------"
        df_out=$(df -h "$KINDLE_ROOT" 2>/dev/null)
        total_size=$(echo "$df_out" | awk 'NR==2 {print $2}')
        used_size=$(echo "$df_out" | awk 'NR==2 {print $3}')
        free_size=$(echo "$df_out" | awk 'NR==2 {print $4}')
        used_percent=$(echo "$df_out" | awk 'NR==2 {print $5}')
        
        echo "Total storage: $total_size"
        echo "Used storage:  $used_size ($used_percent)"
        echo "Free storage:  $free_size"
        echo ""
        
        # File type stats
        echo "FILE TYPES"
        echo "----------"
        # E-books
        ebooks=$(find "$KINDLE_ROOT" -type f -name "*.azw" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.kfx" 2>/dev/null | wc -l)
        echo "E-books: $ebooks files"
        
        # PDFs
        pdfs=$(find "$KINDLE_ROOT" -type f -name "*.pdf" 2>/dev/null | wc -l)
        echo "PDFs: $pdfs files"
        
        # Documents
        docs=$(find "$KINDLE_ROOT" -type f -name "*.doc" -o -name "*.docx" -o -name "*.txt" 2>/dev/null | wc -l)
        echo "Documents: $docs files"
        echo ""
        
        # Top largest files
        echo "TOP 10 LARGEST FILES"
        echo "-------------------"
        find "$KINDLE_ROOT" -type f -size +1M 2>/dev/null | xargs ls -lh 2>/dev/null | sort -rh -k5 | head -10 | 
            awk '{printf("%s (%s)\n", $9, $5)}'
        echo ""
        
        # Recommendations
        echo "RECOMMENDATIONS"
        echo "--------------"
        echo "1. Consider cleaning browser cache"
        echo "2. Check for unused/duplicate e-books"
        echo "3. Remove temporary files with the cleanup tool"
        echo ""
        
        echo "====================================="
        echo "Report generated by StorageTool v$VERSION"
    } > "$report_file"
    
    echo "Report saved to: $report_file"
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Settings menu
settings_menu() {
    while true; do
        clear
        print_colored "$CYAN" "
  _____      _   _   _                 
 / ____|    | | | | (_)                
| (___   ___| |_| |_ _ _ __   __ _ ___ 
 \___ \ / _ \ __| __| | '_ \ / _\` / __|
 ____) |  __/ |_| |_| | | | | (_| \__ \\
|_____/ \___|\__|\__|_|_| |_|\__, |___/
                              __/ |    
                             |___/     
"
        echo "Current settings:"
        echo "--------------------------------"
        echo "1. Show hidden files: $SHOW_HIDDEN_FILES"
        echo "2. Use condensed output: $CONDENSED_OUTPUT"
        echo "3. Debug mode: $DEBUG_MODE"
        echo "4. Back to main menu"
        echo ""
        echo -n "Choose option: "
        read choice
        
        case "$choice" in
            1)
                if $SHOW_HIDDEN_FILES; then
                    SHOW_HIDDEN_FILES=false
                    echo "Hidden files will be hidden"
                else
                    SHOW_HIDDEN_FILES=true
                    echo "Hidden files will be shown"
                fi
                save_config
                sleep 1
                ;;
            2)
                if $CONDENSED_OUTPUT; then
                    CONDENSED_OUTPUT=false
                    echo "Using normal output"
                else
                    CONDENSED_OUTPUT=true
                    echo "Using condensed output"
                fi
                save_config
                sleep 1
                ;;
            3)
                if $DEBUG_MODE; then
                    DEBUG_MODE=false
                    echo "Debug mode disabled"
                else
                    DEBUG_MODE=true
                    echo "Debug mode enabled"
                fi
                save_config
                sleep 1
                ;;
            4)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Smart recommendations
smart_recommendations() {
    clear
    print_colored "$CYAN" "
 _____                                                _       _   _                 
|  __ \                                              | |     | | (_)                
| |__) |___  ___ ___  _ __ ___  _ __ ___   ___ _ __ | |   __| |  _  ___  _ __  ___ 
|  _  // _ \/ __/ _ \| '_ \` _ \| '_ \` _ \ / _ \ '_ \| |  / _\` | | |/ _ \| '_ \/ __|
| | \ \  __/ (_| (_) | | | | | | | | | | |  __/ | | | | | (_| | | | (_) | | | \__ \\
|_|  \_\___|\___\___/|_| |_| |_|_| |_| |_|\___|_| |_|_|  \__,_| |_|\___/|_| |_|___/
                                                                                    
"
    echo "Analyzing your storage for optimization recommendations..."
    echo ""
    
    # Check total space usage first
    df_out=$(df -h "$KINDLE_ROOT" 2>/dev/null)
    used_percent=$(echo "$df_out" | awk 'NR==2 {print $5}' | tr -d '%')
    
    echo "Storage Analysis Complete"
    echo "------------------------"
    echo ""
    
    # Storage-based recommendations
    if [ "$used_percent" -gt 90 ]; then
        print_colored "$RED" "CRITICAL: Your storage is at $used_percent% capacity!"
        echo "Immediate action recommended to free up space."
        echo ""
    elif [ "$used_percent" -gt 75 ]; then
        print_colored "$YELLOW" "WARNING: Your storage is at $used_percent% capacity."
        echo "Consider freeing up some space soon."
        echo ""
    fi
    
    # Look for large files
    echo "Large File Analysis:"
    echo "-------------------"
    large_count=$(find "$KINDLE_ROOT" -type f -size +20M 2>/dev/null | wc -l)
    
    if [ "$large_count" -gt 0 ]; then
        echo "Found $large_count files larger than 20MB."
        echo "Recommendation: Run the 'Scan Large Files' option to identify and review them."
        echo ""
    fi
    
    # Check for system caches
    echo "System Cache Analysis:"
    echo "---------------------"
    browser_cache_size=$(du -sh "$KINDLE_ROOT/browser/cache" 2>/dev/null | cut -f1)
    
    if [ -n "$browser_cache_size" ]; then
        echo "Browser cache is using $browser_cache_size"
        echo "Recommendation: Run the cleanup utility to clear browser cache."
        echo ""
    fi
    
    # Look for potential duplicate books
    echo "Potential Duplicates:"
    echo "-------------------"
    dup_count=$(find "$DOCUMENTS_DIR" -type f -name "*.pdf" -o -name "*.mobi" 2>/dev/null | 
        awk -F "/" '{print $NF}' | sort | uniq -d | wc -l)
    
    if [ "$dup_count" -gt 0 ]; then
        echo "Found $dup_count potentially duplicate file names."
        echo "Recommendation: Run the 'Find Duplicates' option to review them."
        echo ""
    fi
    
    # Check for old log files
    echo "Log File Analysis:"
    echo "-----------------"
    log_size=$(find "$KINDLE_ROOT" -name "*.log" -type f -o -path "*/var/log/*" 2>/dev/null | xargs du -ch 2>/dev/null | grep total$ | cut -f1)
    
    if [ -n "$log_size" ]; then
        echo "Log files are using $log_size of space"
        echo "Recommendation: Run the cleanup utility to remove old log files."
        echo ""
    fi
    
    echo "Press any key to continue..."
    read -n 1 -s
}

# Schedule regular scans
schedule_scan() {
    clear
    print_colored "$CYAN" "
  _____      _              _       _      
 / ____|    | |            | |     | |     
| (___   ___| |__   ___  __| |_   _| | ___ 
 \___ \ / __| '_ \ / _ \/ _\` | | | | |/ _ \\
 ____) | (__| | | |  __/ (_| | |_| | |  __/
|_____/ \___|_| |_|\___|\__,_|\__,_|_|\___|
                                           
"
    echo "Schedule a regular storage scan"
    echo "-------------------------------"
    echo ""
    
    echo "This will create a cron job to run storage analysis regularly"
    echo "and save reports in your documents folder."
    echo ""
    
    echo "Choose scan frequency:"
    echo "1. Daily"
    echo "2. Weekly"
    echo "3. Monthly"
    echo "4. Remove scheduled scans"
    echo "5. Back to main menu"
    echo ""
    echo -n "Enter choice: "
    read choice
    
    case "$choice" in
        1)
            # Daily at 3:00 AM
            cron_time="0 3 * * *"
            cron_desc="daily at 3:00 AM"
            ;;
        2)
            # Weekly on Sunday at 3:00 AM
            cron_time="0 3 * * 0"
            cron_desc="weekly on Sunday at 3:00 AM"
            ;;
        3)
            # Monthly on 1st at 3:00 AM
            cron_time="0 3 1 * *"
            cron_desc="monthly on the 1st at 3:00 AM"
            ;;
        4)
            # Remove cron job
            if crontab -l 2>/dev/null | grep -q "storagetool.sh"; then
                (crontab -l 2>/dev/null | grep -v "storagetool.sh") | crontab -
                echo "Scheduled scans removed."
            else
                echo "No scheduled scans found."
            fi
            sleep 2
            return
            ;;
        5)
            return
            ;;
        *)
            echo "Invalid option."
            sleep 2
            return
            ;;
    esac
    
    # Create cron job
    if [ -n "$cron_time" ]; then
        # Create the auto-scan script
        auto_script="$SCRIPT_DIR/autoscan.sh"
        
        echo "#!/bin/sh" > "$auto_script"
        echo "# Auto-generated by StorageTool" >> "$auto_script"
        echo "$SCRIPT_DIR/storagetool.sh --autoscan" >> "$auto_script"
        
        chmod +x "$auto_script"
        
        # Add to crontab if possible
        if command -v crontab >/dev/null; then
            (crontab -l 2>/dev/null | grep -v "storagetool.sh"; echo "$cron_time $auto_script") | crontab -
            echo "Scan scheduled $cron_desc"
        else
            echo "Crontab not available on this device."
            echo "Automatic scheduling not supported."
        fi
    fi
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Main menu
main_menu() {
    load_config
    
    while true; do
        clear
        print_colored "$CYAN" "
  _____ _                       _______          _ 
 / ____| |                     |__   __|        | |
| (___ | |_ ___  _ __ __ _  __ _  | | ___   ___ | |
 \___ \| __/ _ \| '__/ _\` |/ _\` | | |/ _ \ / _ \| |
 ____) | || (_) | | | (_| | (_| | | | (_) | (_) | |
|_____/ \__\___/|_|  \__,_|\__, | |_|\___/ \___/|_|
                            __/ |                  
                           |___/                   
"
        print_colored "$GREEN" "Version $VERSION"
        echo "A storage analysis and management tool for Kindle"
        echo ""
        
        echo "MAIN MENU"
        echo "---------"
        echo "1. Storage Overview"
        echo "2. Scan Large Files"
        echo "3. Analyze by File Type"
        echo "4. File Browser"
        echo "5. Cleanup Utility"
        echo "6. Recent Files"
        echo "7. Find Duplicates"
        echo "8. Smart Recommendations"
        echo "9. Export Storage Report"
        echo "10. Schedule Regular Scans"
        echo "11. Settings"
        echo "12. Exit"
        echo ""
        echo -n "Enter choice: "
        read choice
        
        case "$choice" in
            1)
                get_disk_info
                ;;
            2)
                scan_large_files
                ;;
            3)
                analyze_by_type
                ;;
            4)
                browse_directory
                ;;
            5)
                cleanup_utility
                ;;
            6)
                scan_recent_files
                ;;
            7)
                find_duplicates
                ;;
            8)
                smart_recommendations
                ;;
            9)
                export_storage_report
                ;;
            10)
                schedule_scan
                ;;
            11)
                settings_menu
                ;;
            12)
                cleanup
                echo "Thank you for using StorageTool!"
                exit 0
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Parse command line arguments
handle_args() {
    case "$1" in
        --autoscan)
            # Called from cron job - run scan and generate report
            init_environment
            load_config
            export_storage_report
            cleanup
            exit 0
            ;;
        --help)
            echo "StorageTool - Kindle Storage Analysis and Management Tool"
            echo "Usage: storagetool.sh [OPTION]"
            echo ""
            echo "Options:"
            echo "  --help      Display this help message"
            echo "  --autoscan  Run automatic scan (for scheduled tasks)"
            echo "  --version   Display version information"
            exit 0
            ;;
        --version)
            echo "StorageTool v$VERSION"
            exit 0
            ;;
        *)
            # No arguments or unknown arguments - launch interactive mode
            ;;
    esac
}

# Entry point
handle_args "$1"
init_environment
trap cleanup EXIT
main_menu
