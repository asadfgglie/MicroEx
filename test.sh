#!/bin/bash

make build
# Check if the build was successful
if [ $? -ne 0 ]; then
    echo "Build failed. Please check the errors."
    exit 1
fi

# Ensure the result directory exists
rm -rf test/result/*
mkdir -p test/result/
mkdir -p test/result/error_case

# Loop through all .microex files in the test directory
for test_file in test/*.microex; do
    # Extract the base name of the test file
    base_name=$(basename "$test_file" .microex)
    
    # Compile the test file and redirect output to the result directory
    ./microex_c -f "$test_file" -v -o "test/result/$base_name" > test/result/$base_name.log
    if [ $? -ne 0 ]; then
        echo "Test $test_file failed. Please check the errors."
        exit 1
    fi
done

for test_file in test/error_case/*.microex; do
    # Extract the base name of the test file
    base_name=$(basename "$test_file" .microex)
    
    # Compile the test file and redirect output to the result directory
    ./microex_c -f "$test_file" -v -o "test/result/error_case/$base_name" > "test/result/error_case/$base_name.log"
    status=$?
    if [ $status -ne 0 ] && [ $status -ne 1 ]; then
        echo "Test $test_file failed. Please check the errors."
        exit 1
    fi
done

echo "Compilation completed. Results are in the test/result directory."