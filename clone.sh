#!/bin/bash

# Path to the input file
input_file="./targets/0x9f3098a180fab2954fcc728a949a2d6cdfcc426f.txt"

# Path to the executable
executable="./profanity.x64"

# Timeout duration in seconds
timeout_duration=10

# Path to the output file
output_file="./clones/0x9f3098a180fab2954fcc728a949a2d6cdfcc426f.txt"

# Maximum number of concurrent jobs (threads)
max_jobs=5

# Clear the output file at the start
> "$output_file"

# Function to run the command for each hex string
run_command() {
    local hex_string="$1"
    
    echo "Running command: timeout ${timeout_duration}s $executable --matching $hex_string"
    timeout ${timeout_duration}s $executable --matching "$hex_string" > temp_output_"$hex_string".txt 2>&1

    # Check if the command was terminated
    if [ $? -eq 124 ]; then
        echo "Command timed out after ${timeout_duration} seconds"
    fi

    # Process the output file using `strings` to ensure text extraction
    if [ -s temp_output_"$hex_string".txt ]; then
        # Use `strings` to extract printable characters and `grep` to find "Private"
        strings temp_output_"$hex_string".txt | grep -i "Score:  4" >> "$output_file"
    else
        echo "No output to process for command with input: $hex_string"
    fi

    # Clean up temporary file
    rm -f temp_output_"$hex_string".txt
}

# Control concurrent jobs using a job count limiter
job_limiter() {
    while [ "$(jobs | wc -l)" -ge "$max_jobs" ]; do
        sleep 0.5
    done
}

# Read each line from the input file
while IFS= read -r line; do
    # Strip any trailing newlines or spaces
    hex_string=$(echo "$line" | xargs)

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
