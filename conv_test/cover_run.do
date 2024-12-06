do wave.do
run 100 ms
coverage report -output report.txt -srcfile=* -assert -directive -cvg -codeAll

