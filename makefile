.PHONY: clean build_hw test

build_hw: build/microex_c_hw
	@cp build/microex_c_hw microex_c_hw

build/microex_c_hw: build/lex_hw.yy.c
	@mkdir -p build
	@gcc -o build/microex_c_hw build/lex_hw.yy.c -lfl

build/lex_hw.yy.c: microex/microex_scanner_hw.l
	@mkdir -p build
	@lex -o build/lex_hw.yy.c microex/microex_scanner_hw.l

build: build/microex_c
	@cp build/microex_c microex_c

build/microex_c: build/lex.yy.c build/y.tab.c build/y.tab.h
	@mkdir -p build
	@gcc -o build/microex_c build/y.tab.c build/lex.yy.c -lfl

build/y.tab.c build/y.tab.h: microex/microex_parser.y
	@mkdir -p build
	@yacc -d -o build/y.tab.c microex/microex_parser.y

build/lex.yy.c: microex/microex_scanner.l
	@mkdir -p build
	@lex -o build/lex.yy.c microex/microex_scanner.l

clean:
	@rm -rf build
	@rm -f microex_c*
	@rm -f test/result/*

test: build/microex_c_hw
	@./test_hw.sh