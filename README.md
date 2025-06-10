# Micro/Ex

 ## Build scoures
 Run `make build` to get excutable compiler `microex_c`, then use `./microex_c <file>` to compile the code.

 Or run `make test` to automatically complie lex, yacc, c, and compile test code.

 All test result will be saved in `test/result`.

 ## Src code
 所有的原始碼都存放在`microex`, 其中`_scanner`後綴的是scanner, `_parser`後綴的則是parser

 有附帶`_hw`後綴的是過去的作業內容，與期末專案無關

 ## Test
 所有的測試資料都存放在`test`中

 其中`test/hw`是過去作業內容，與期末專案無關

 `*.microex`是被編譯的原始程式碼, `.in`是被`simulator.py`作為輸入的測試資料

 `test/error_case`則是語法錯誤的範例測資

 `test/result`是編譯後的結果, 其中`.log`是編譯器在編譯過程中的中間資訊輸出, `.out`是編譯完成後使用`simulator.py`模擬執行後的結果