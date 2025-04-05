.PHONY: clean build test

build: build/microex_c
	@cp build/microex_c microex_c

build/microex_c: build/lex.yy.c
	@mkdir -p build
	@gcc -o build/microex_c build/lex.yy.c -lfl

build/lex.yy.c: microex/microex_scanner.l
	@mkdir -p build
	@lex -o build/lex.yy.c microex/microex_scanner.l

clean:
	@rm -rf build
	@rm -f microex_c
	@rm -f test/result/*

test:
	@./test.sh