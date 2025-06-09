#!/bin/bash

make build_hw
# Check if the build was successful
if [ $? -ne 0 ]; then
    echo "Build failed. Please check the errors."
    exit 1
fi

# Ensure the result directory exists
mkdir -p test/result/hw
rm -f test/result/hw/*

# Loop through all .microex files in the test directory
for test_file in test/hw/*.microex; do
    # Extract the base name of the test file
    base_name=$(basename "$test_file" .microex)
    
    # Compile the test file and redirect output to the result directory
    ./microex_c_hw "$test_file" > "test/result/hw/$base_name"
done

echo "Compilation completed. Results are in the test/result/hw directory."