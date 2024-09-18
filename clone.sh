#!/bin/bash

# Default values
input_file=""
output_file=""
timeout_duration=10
executable="./profanity.x64"
max_jobs=5

# Function to display usage information
usage() {
    echo "Usage: $0 --target target-name.txt --output target-name.txt"
    exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --target)
            input_file="$2"
            shift
            ;;
        --output)
            output_file="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

# Check if input and output files are specified
if [[ -z "$input_file" || -z "$output_file" ]]; then
    usage
fi

# Check if the input file exists
if [[ ! -f "$input_file" ]]; then
    echo "Input file $input_file does not exist."
    exit 1
fi

# Ensure the output directory exists
output_dir=$(dirname "$output_file")
mkdir -p "$output_dir"

# Clear the output file at the start
> "$output_file"

# Function to run the command for each hex string
run_command() {
    local hex_string="$1"
    
    # Create a temporary file
    local temp_output
    temp_output=$(mktemp)

    echo "Running command: timeout ${timeout_duration}s $executable --matching $hex_string"
    timeout ${timeout_duration}s "$executable" --matching "$hex_string" > "$temp_output" 2>&1

    # Check if the command was terminated
    if [ $? -eq 124 ]; then
        echo "Command timed out after ${timeout_duration} seconds"
    fi

    # Process the output file using `strings` to ensure text extraction
    if [ -s "$temp_output" ]; then
        # Use `strings` to extract printable characters and `grep` to find "Score:  4"
        strings "$temp_output" | grep -i "Score:  4" >> "$output_file"
    else
        echo "No output to process for command with input: $hex_string"
    fi

    # Clean up temporary file
    rm -f "$temp_output"
}

# Control concurrent jobs using a job count limiter
job_limiter() {
    while [ "$(jobs | wc -l)" -ge "$max_jobs" ]; do
        sleep 0.5
    done
}

# Trap to clean up temporary files on script exit
trap 'rm -f temp_output_*' EXIT

# Read each line from the input file
while IFS= read -r line; do
    # Strip any trailing newlines or spaces
    hex_string="${line//[[:space:]]/}"

    # Skip empty lines
    if [ -z "$hex_string" ]; then
        echo "Skipping empty line"
        continue
    fi

    # Wait for available job slots before running the next command
    job_limiter

    # Run the command in the background
    run_command "$hex_string" &

done < "$input_file"

# Wait for all background jobs to finish
wait

echo "All commands have been executed. Relevant output has been saved to $output_file."
