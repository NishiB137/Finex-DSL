CXX = g++
CXXFLAGS = -std=c++14 -Wall -g
LEX = flex
YACC = bison

# Target executable
TARGET = finex_parser

# Source files
LEX_SRC = lexer.l
YACC_SRC = parser.y
AST_SRC = ast.cpp
SYMTAB_SRC = symbol_table.cpp
SEMANTIC_SRC = semantic_analyzer.cpp

LEX_OUT = lex.yy.c
YACC_OUT = y.tab.c
YACC_HDR = y.tab.h

# Object files
OBJS = y.tab.o lex.yy.o ast.o symbol_table.o semantic_analyzer.o

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(OBJS)

y.tab.c y.tab.h: $(YACC_SRC)
	$(YACC) -d -o y.tab.c $(YACC_SRC)

lex.yy.c: $(LEX_SRC) y.tab.h
	$(LEX) $(LEX_SRC)

y.tab.o: y.tab.c ast.hpp symbol_table.hpp semantic_analyzer.hpp
	$(CXX) $(CXXFLAGS) -c y.tab.c

lex.yy.o: lex.yy.c y.tab.h
	$(CXX) $(CXXFLAGS) -c lex.yy.c

ast.o: $(AST_SRC) ast.hpp
	$(CXX) $(CXXFLAGS) -c $(AST_SRC)

symbol_table.o: $(SYMTAB_SRC) symbol_table.hpp ast.hpp
	$(CXX) $(CXXFLAGS) -c $(SYMTAB_SRC)

semantic_analyzer.o: $(SEMANTIC_SRC) semantic_analyzer.hpp symbol_table.hpp ast.hpp
	$(CXX) $(CXXFLAGS) -c $(SEMANTIC_SRC)

clean:
	rm -f $(TARGET) $(OBJS) $(LEX_OUT) $(YACC_OUT) $(YACC_HDR)

test: $(TARGET)
	./$(TARGET) test_input2.fx

.PHONY: all clean test