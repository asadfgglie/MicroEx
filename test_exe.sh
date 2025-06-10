#!/bin/bash

make test_compile
# Check if the build was successful
if [ $? -ne 0 ]; then
    echo "Build failed. Please check the errors."
    exit 1
fi

mkdir -p test/result/
rm -rf test/result/*.out

for test_file in test/*.microex; do
    # Extract the base name of the test file
    base_name=$(basename "$test_file" .microex)
    
    echo "Execute $base_name..."
    cat test/$base_name.in | python3 simulator.py -f "test/result/$base_name" > test/result/$base_name.out
    if [ $? -ne 0 ]; then
        echo "Test $test_file failed. Please check the errors."
        exit 1
    fi
    echo "Execute $base_name done"
done