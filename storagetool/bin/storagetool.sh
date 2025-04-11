#!/bin/sh
# StorageTool - Kindle Book Storage Analysis and Management Tool

# Variables
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$SCRIPT_DIR/.storagetool_config"
VERSION="2.0.0"

# Default directories to analyze
KINDLE_ROOT="/mnt/us"
DOCUMENTS_DIR="/mnt/us/documents"
TEMP_DIR="/tmp/storagetool"
BOOKS_DIR="/mnt/us/documents"

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
    echo "BOOKS_DIR=$BOOKS_DIR" >> "$CONFIG_FILE"
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

# Format file size without using bc
format_size() {
    size="$1"
    # 1GB = 1073741824 bytes
    if [ "$size" -gt 1073741824 ]; then
        # Integer division for GB (with 1 decimal place)
        gb_whole=$((size / 1073741824))
        gb_decimal=$(((size % 1073741824) * 10 / 1073741824))
        echo "${gb_whole}.${gb_decimal}G"
    # 1MB = 1048576 bytes
    elif [ "$size" -gt 1048576 ]; then
        # Integer division for MB (with 1 decimal place)
        mb_whole=$((size / 1048576))
        mb_decimal=$(((size % 1048576) * 10 / 1048576))
        echo "${mb_whole}.${mb_decimal}M"
    # 1KB = 1024 bytes
    elif [ "$size" -gt 1024 ]; then
        # Integer division for KB (with 1 decimal place)
        kb_whole=$((size / 1024))
        kb_decimal=$(((size % 1024) * 10 / 1024))
        echo "${kb_whole}.${kb_decimal}K"
    else
        echo "${size}B"
    fi
}

# Generate ASCII bar chart without using bc
generate_bar_chart() {
    total=$1
    value=$2
    width=40
    
    # Calculate filled positions using simple math
    # To avoid division by zero
    if [ "$total" -eq 0 ]; then
        total=1
    fi
    
    # Calculate filled positions (scaled to width)
    filled=$((width * value / total))
    
    # Build the bar
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
    
    # Calculate percentage (integer value is enough)
    percent=$((100 * value / total))
    echo "$bar (${percent}%)"
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
print_colored "$CYAN" "
██████  ██ ███████ ██   ██     ██ ███    ██ ███████  ██████  
██   ██ ██ ██      ██  ██      ██ ████   ██ ██      ██    ██ 
██   ██ ██ ███████ █████       ██ ██ ██  ██ █████   ██    ██ 
██   ██ ██      ██ ██  ██      ██ ██  ██ ██ ██      ██    ██ 
██████  ██ ███████ ██   ██     ██ ██   ████ ██       ██████  
                                                             
                                                            
"
                        
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

# Scan books directory
scan_books_directory() {
    clear
    print_colored "$CYAN" "
██████   ██████   ██████  ██   ██     ███████  ██████  █████  ███    ██ 
██   ██ ██    ██ ██    ██ ██  ██      ██      ██      ██   ██ ████   ██ 
██████  ██    ██ ██    ██ █████       ███████ ██      ███████ ██ ██  ██ 
██   ██ ██    ██ ██    ██ ██  ██           ██ ██      ██   ██ ██  ██ ██ 
██████   ██████   ██████  ██   ██     ███████  ██████ ██   ██ ██   ████ 
                                                                       
                                                   
                                                   
"
    print_colored "$GREEN" "Scanning for books in $BOOKS_DIR (this may take a while)..."
    echo ""
    
    # Finding book files - using numeric sort
    echo "Book files found in directory:"
    echo ""
    
    # Create temporary file for find patterns
    echo "*.pdf" > "$TEMP_DIR/book_extensions.txt"
    echo "*.epub" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.mobi" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw3" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw4" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.kfx" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.txt" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.doc" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.docx" >> "$TEMP_DIR/book_extensions.txt"
    
    # Build the find command with 'or' conditions for each book extension
    find_cmd="find \"$BOOKS_DIR\" -type f \\( "
    first=true
    while read -r ext; do
        if $first; then
            find_cmd="$find_cmd-name \"$ext\""
            first=false
        else
            find_cmd="$find_cmd -o -name \"$ext\""
        fi
    done < "$TEMP_DIR/book_extensions.txt"
    find_cmd="$find_cmd \\) 2>/dev/null"
    
    # Count total books first
    total_books=$(eval "$find_cmd" | wc -l)
    
    # Get total size
    total_size_kb=$(eval "$find_cmd" | xargs du -k 2>/dev/null | awk '{sum += $1} END {print sum}')
    
    # Format total size
    if [ -z "$total_size_kb" ] || [ "$total_size_kb" -eq 0 ]; then
        total_size_str="0KB"
    elif [ "$total_size_kb" -gt 1048576 ]; then  # Greater than 1GB (in KB)
        size_gb=$((total_size_kb / 1024 / 1024))
        size_decimal=$(((total_size_kb % (1024*1024)) * 10 / (1024*1024)))
        total_size_str="${size_gb}.${size_decimal}GB"
    elif [ "$total_size_kb" -gt 1024 ]; then   # Greater than 1MB (in KB)
        size_mb=$((total_size_kb / 1024))
        size_decimal=$(((total_size_kb % 1024) * 10 / 1024))
        total_size_str="${size_mb}.${size_decimal}MB"
    else
        total_size_str="${total_size_kb}KB"
    fi
    
    echo "Total books found: $total_books ($total_size_str)"
    echo ""
    
    # Find largest books
    echo "Top 20 largest books:"
    echo ""
    
    # Run the command with proper handling for spaces in filenames
    eval "$find_cmd" | xargs du -k 2>/dev/null | sort -rn | head -20 > "$TEMP_DIR/large_files_raw.txt"
    
    # Check if we found any files
    if [ ! -s "$TEMP_DIR/large_files_raw.txt" ]; then
        echo "No book files found in $BOOKS_DIR."
        echo ""
        echo "Press any key to continue..."
        read -n 1 -s
        return
    fi
    
    # Format the output with readable sizes
    line_num=1
    while read -r size_kb filepath; do
        # Calculate size in appropriate units
        if [ "$size_kb" -gt 1048576 ]; then  # Greater than 1GB (in KB)
            size_gb=$((size_kb / 1024 / 1024))
            size_decimal=$(((size_kb % (1024*1024)) * 10 / (1024*1024)))
            size_str="${size_gb}.${size_decimal}GB"
        elif [ "$size_kb" -gt 1024 ]; then   # Greater than 1MB (in KB)
            size_mb=$((size_kb / 1024))
            size_decimal=$(((size_kb % 1024) * 10 / 1024))
            size_str="${size_mb}.${size_decimal}MB"
        else
            size_str="${size_kb}KB"
        fi
        
        # Get filename and extension
        filename=$(basename "$filepath")
        ext=$(echo "$filepath" | awk -F. '{if (NF>1) print $NF}' | tr '[:upper:]' '[:lower:]')
        
        # Print formatted line
        printf "%2d. %s (%s) [%s]\n" "$line_num" "$filename" "$size_str" "$ext"
        
        line_num=$((line_num + 1))
    done < "$TEMP_DIR/large_files_raw.txt" | tee "$LARGE_FILES"
    
    # Count by file type
    echo ""
    echo "Books by file type:"
    
    while read -r ext; do
        # Remove leading *
        clean_ext=$(echo "$ext" | sed 's/^\*//')
        count=$(eval "$find_cmd" | grep -i "$clean_ext$" | wc -l)
        echo "- $(echo "$clean_ext" | tr '[:lower:]' '[:upper:]'): $count files"
    done < "$TEMP_DIR/book_extensions.txt"
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Analyze storage by file type
analyze_by_type() {
    clear
    print_colored "$CYAN" "
███████ ██ ██      ███████ ████████ ██    ██ ██████  ███████ ███████ 
██      ██ ██      ██         ██     ██  ██  ██   ██ ██      ██      
█████   ██ ██      █████      ██      ████   ██████  █████   ███████ 
██      ██ ██      ██         ██       ██    ██      ██           ██ 
██      ██ ███████ ███████    ██       ██    ██      ███████ ███████ 
                                                                               
"
    print_colored "$GREEN" "Analyzing books by file type in $BOOKS_DIR..."
    echo ""
    
    # Define common file extensions and their descriptions
    echo "Collecting data on file types..."
    
    > "$TYPE_SUMMARY"
    
    # E-books
    find "$BOOKS_DIR" -type f -name "*.azw" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.kfx" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "E-books:", $1)}' >> "$TYPE_SUMMARY"
    
    # PDFs
    find "$BOOKS_DIR" -type f -name "*.pdf" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "PDFs:", $1)}' >> "$TYPE_SUMMARY"
    
    # Documents
    find "$BOOKS_DIR" -type f -name "*.doc" -o -name "*.docx" -o -name "*.txt" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "Documents:", $1)}' >> "$TYPE_SUMMARY"
    
    # EPUBs (separate category)
    find "$BOOKS_DIR" -type f -name "*.epub" 2>/dev/null |
        wc -l | awk '{printf("%-20s %8d files\n", "EPUBs:", $1)}' >> "$TYPE_SUMMARY"
    
    # Now calculate sizes
    echo "Calculating sizes for each type (this may take a while)..."
    
    # E-books size
    ebook_size=$(find "$BOOKS_DIR" -type f -name "*.azw" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.kfx" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$ebook_size" ] && ebook_size=0
    
    # PDFs size
    pdf_size=$(find "$BOOKS_DIR" -type f -name "*.pdf" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$pdf_size" ] && pdf_size=0
    
    # Documents size
    doc_size=$(find "$BOOKS_DIR" -type f -name "*.doc" -o -name "*.docx" -o -name "*.txt" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$doc_size" ] && doc_size=0
    
    # EPUB size
    epub_size=$(find "$BOOKS_DIR" -type f -name "*.epub" 2>/dev/null -exec du -cb {} \; | 
        grep "total$" | tail -1 | cut -f1)
    [ -z "$epub_size" ] && epub_size=0
    
    # Calculate total content size for percentage
    total_analyzed=$((ebook_size + pdf_size + doc_size + epub_size))
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
    
    echo "EPUBs:      $(format_size "$epub_size")"
    generate_bar_chart "$total_analyzed" "$epub_size"
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Scan for recent files
scan_recent_files() {
    clear
    print_colored "$CYAN" "
██████  ███████  ██████ ███████ ███    ██ ████████ 
██   ██ ██      ██      ██      ████   ██    ██    
██████  █████   ██      █████   ██ ██  ██    ██    
██   ██ ██      ██      ██      ██  ██ ██    ██    
██   ██ ███████  ██████ ███████ ██   ████    ██    
                                                  
                             
"
    print_colored "$GREEN" "Analyzing recently added books in $BOOKS_DIR..."
    echo ""
    
    # Find files modified in the last 30 days
    echo "Books added/modified in the last 30 days (largest first):"
    echo ""
    
    # Build the find command for books only
    find_cmd="find \"$BOOKS_DIR\" -type f \\( "
    echo "*.pdf" > "$TEMP_DIR/book_extensions.txt"
    echo "*.epub" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.mobi" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw3" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw4" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.kfx" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.txt" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.doc" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.docx" >> "$TEMP_DIR/book_extensions.txt"
    
    first=true
    while read -r ext; do
        if $first; then
            find_cmd="$find_cmd-name \"$ext\""
            first=false
        else
            find_cmd="$find_cmd -o -name \"$ext\""
        fi
    done < "$TEMP_DIR/book_extensions.txt"
    find_cmd="$find_cmd \\) -mtime -30 2>/dev/null"
    
    # Using find and du directly with numeric sort
    eval "$find_cmd" | xargs du -k 2>/dev/null | sort -rn | head -15 > "$TEMP_DIR/recent_files_raw.txt"
    
    # Format the output with readable sizes
    line_num=1
    while read -r size_kb filepath; do
        # Calculate size in appropriate units
        if [ "$size_kb" -gt 1048576 ]; then  # Greater than 1GB (in KB)
            size_gb=$((size_kb / 1024 / 1024))
            size_decimal=$(((size_kb % (1024*1024)) * 10 / (1024*1024)))
            size_str="${size_gb}.${size_decimal}GB"
        elif [ "$size_kb" -gt 1024 ]; then   # Greater than 1MB (in KB)
            size_mb=$((size_kb / 1024))
            size_decimal=$(((size_kb % 1024) * 10 / 1024))
            size_str="${size_mb}.${size_decimal}MB"
        else
            size_str="${size_kb}KB"
        fi
        
        # Get filename and extension
        filename=$(basename "$filepath")
        ext=$(echo "$filepath" | awk -F. '{if (NF>1) print $NF}' | tr '[:upper:]' '[:lower:]')
        
        # Print formatted line
        printf "%2d. %s (%s) [%s]\n" "$line_num" "$filename" "$size_str" "$ext"
        
        line_num=$((line_num + 1))
    done < "$TEMP_DIR/recent_files_raw.txt" | tee "$RECENT_FILES"
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# Find duplicate files (basic implementation - can be expanded)
find_duplicates() {
    clear
    print_colored "$CYAN" "
██████  ██    ██ ██████  ███████ ███████ 
██   ██ ██    ██ ██   ██ ██      ██      
██   ██ ██    ██ ██████  █████   ███████ 
██   ██ ██    ██ ██      ██           ██ 
██████   ██████  ██      ███████ ███████ 
                                        
                                             
"
    print_colored "$GREEN" "Scanning for duplicate books in $BOOKS_DIR..."
    echo ""
    
    # This is a simple duplicate finder based on filenames
    # A more thorough approach would compare file checksums, but that's resource-intensive
    
    echo "Looking for duplicate books..."
    
    # Build the find command with 'or' conditions for each book extension
    find_cmd="find \"$BOOKS_DIR\" -type f \\( "
    echo "*.pdf" > "$TEMP_DIR/book_extensions.txt"
    echo "*.epub" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.mobi" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw3" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.azw4" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.kfx" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.txt" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.doc" >> "$TEMP_DIR/book_extensions.txt"
    echo "*.docx" >> "$TEMP_DIR/book_extensions.txt"
    
    first=true
    while read -r ext; do
        if $first; then
            find_cmd="$find_cmd-name \"$ext\""
            first=false
        else
            find_cmd="$find_cmd -o -name \"$ext\""
        fi
    done < "$TEMP_DIR/book_extensions.txt"
    find_cmd="$find_cmd \\) 2>/dev/null"
    
    # Find by filename without path
    eval "$find_cmd" | awk -F"/" '{print $NF}' | sort | uniq -d | head -20 > "$TEMP_DIR/dupes.txt"
    
    if [ -s "$TEMP_DIR/dupes.txt" ]; then
        echo "Potential duplicate books found (based on filename):"
        echo ""
        cat "$TEMP_DIR/dupes.txt" | nl
        echo ""
        echo "Note: This only checks for identical filenames, not content."
    else
        echo "No duplicate book filenames found in $BOOKS_DIR."
    fi
    
    echo ""
    echo "Press any key to continue..."
    read -n 1 -s
}

# This function has been removed by user request

# Settings menu
settings_menu() {
    while true; do
        clear
        print_colored "$CYAN" "
███████ ███████ ████████ ████████ ██ ███    ██  ██████  ███████ 
██      ██         ██       ██    ██ ████   ██ ██       ██      
███████ █████      ██       ██    ██ ██ ██  ██ ██   ███ ███████ 
     ██ ██         ██       ██    ██ ██  ██ ██ ██    ██      ██ 
███████ ███████    ██       ██    ██ ██   ████  ██████  ███████   
"
        echo "Current settings:"
        echo "--------------------------------"
        echo "1. Show hidden files: $SHOW_HIDDEN_FILES"
        echo "2. Use condensed output: $CONDENSED_OUTPUT"
        echo "3. Debug mode: $DEBUG_MODE"
        echo "4. Books directory: $BOOKS_DIR"
        echo "5. Back to main menu"
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
                echo "Current books directory: $BOOKS_DIR"
                echo "Enter new path (or press Enter to keep current):"
                read -r new_dir
                if [ -n "$new_dir" ]; then
                    # Check if directory exists
                    if [ -d "$new_dir" ]; then
                        BOOKS_DIR="$new_dir"
                        echo "Books directory updated to: $BOOKS_DIR"
                        save_config
                    else
                        echo "Directory does not exist. Create it? (y/n)"
                        read -r confirm
                        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                            mkdir -p "$new_dir"
                            if [ -d "$new_dir" ]; then
                                BOOKS_DIR="$new_dir"
                                echo "Directory created and setting updated to: $BOOKS_DIR"
                                save_config
                            else
                                echo "Failed to create directory."
                            fi
                        else
                            echo "Setting unchanged."
                        fi
                    fi
                fi
                sleep 2
                ;;
            5)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Main menu
main_menu() {
    load_config
    
    while true; do
        clear
        print_colored "$CYAN" "
   _____ _                          _______          _ 
  / ____| |                        |__   __|        | |
 | (___ | |_ ___  _ __ __ _  __ _  ___| | ___   ___ | |
  \___ \| __/ _ \| '__/ _` |/ _` |/ _ \ |/ _ \ / _ \| |
  ____) | || (_) | | | (_| | (_| |  __/ | (_) | (_) | |
 |_____/ \__\___/|_|  \__,_|\__, |\___|_|\___/ \___/|_|
                             __/ |                     
                            |___/                     
"
        print_colored "$GREEN" "Version $VERSION"
        echo "https://github.com/jkpth/StorageTool"
        echo ""
        
        echo "MAIN MENU"
        echo "---------"
        echo "1. Storage Overview"
        echo "2. Scan Books Directory"
        echo "3. Analyze by File Type"
        echo "4. Recent Files"
        echo "5. Find Duplicates"
        echo "6. Settings"
        echo "7. Exit"
        echo ""
        echo -n "Enter choice: "
        read choice
        
        
        
        
        case "$choice" in
            1)
                get_disk_info
                ;;
            2)
                scan_books_directory
                ;;
            3)
                analyze_by_type
                ;;
            4)
                scan_recent_files
                ;;
            5)
                find_duplicates
                ;;
            6)
                settings_menu
                ;;
            7)
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
            cleanup
            exit 0
            ;;
        --help)
            echo "StorageTool - Kindle Storage Analysis and Management Tool"
            echo "Usage: storagetool.sh [OPTION]"
            echo ""
            echo "Options:"
            echo "  --help      Display this help message"
            # Removed scheduling functionality
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
