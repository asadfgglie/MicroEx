echo "cat README.md"
cat README.md

echo ""
echo "===================="
echo ""

echo "cat microex/microex_scanner.l"
cat microex/microex_scanner.l

echo ""
echo "===================="
echo ""

for test_file in test/*.microex; do
    # Extract the base name of the test file
    echo "cat $test_file"
    cat $test_file

    echo ""
    echo "===================="
    echo ""
done

echo "cat makefile"
cat makefile

echo ""
echo "===================="
echo ""

echo "cat test.sh"
cat test.sh

echo ""
echo "===================="
echo ""

echo "make test"
make test

for test_file in test/result/*; do
    # Extract the base name of the test file
    echo "cat $test_file"
    cat $test_file

    echo ""
    echo "===================="
    echo ""
done