CXX = g++
# -I adds Header_Files to the include path.
# This makes sure the compiler finds headers even if your relative paths in .cpp are slightly off.
CXXFLAGS = -std=c++14 -Wall -g -I$(INC_DIR)
LEX = flex
YACC = bison

# Directory Paths
SRC_DIR = Source_Code
INC_DIR = Header_Files

# Target executable
TARGET = finex

# Source files
LEX_SRC = $(SRC_DIR)/lexer.l
YACC_SRC = $(SRC_DIR)/parser.y
AST_SRC = $(SRC_DIR)/ast.cpp
SYMTAB_SRC = $(SRC_DIR)/symbol_table.cpp
SEMANTIC_SRC = $(SRC_DIR)/semantic_analyzer.cpp

# Generated files
LEX_OUT = lex.yy.c
YACC_OUT = y.tab.c
YACC_HDR = y.tab.h

# Object files
OBJS = y.tab.o lex.yy.o ast.o symbol_table.o semantic_analyzer.o

# ==========================================
# Build Rules
# ==========================================

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(OBJS)

# 1. Generate Parser (C and H files)
y.tab.c y.tab.h: $(YACC_SRC)
	$(YACC) -d -o y.tab.c $(YACC_SRC)

# 2. Generate Lexer
lex.yy.c: $(LEX_SRC) y.tab.h
	$(LEX) -o lex.yy.c $(LEX_SRC)

# 3. Compile Parser Object
# Note: Added $(INC_DIR)/ prefix to headers so Make finds them
y.tab.o: y.tab.c $(INC_DIR)/ast.hpp $(INC_DIR)/symbol_table.hpp $(INC_DIR)/semantic_analyzer.hpp
	$(CXX) $(CXXFLAGS) -c y.tab.c

# 4. Compile Lexer Object
lex.yy.o: lex.yy.c y.tab.h
	$(CXX) $(CXXFLAGS) -c lex.yy.c

# 5. Compile AST Object
ast.o: $(AST_SRC) $(INC_DIR)/ast.hpp
	$(CXX) $(CXXFLAGS) -c $(AST_SRC)

# 6. Compile Symbol Table Object
symbol_table.o: $(SYMTAB_SRC) $(INC_DIR)/symbol_table.hpp $(INC_DIR)/ast.hpp
	$(CXX) $(CXXFLAGS) -c $(SYMTAB_SRC)

# 7. Compile Semantic Analyzer Object
semantic_analyzer.o: $(SEMANTIC_SRC) $(INC_DIR)/semantic_analyzer.hpp $(INC_DIR)/symbol_table.hpp $(INC_DIR)/ast.hpp
	$(CXX) $(CXXFLAGS) -c $(SEMANTIC_SRC)

# Clean up build files
clean:
	rm -f $(TARGET) $(OBJS) $(LEX_OUT) $(YACC_OUT) $(YACC_HDR)

# Test execution
test: $(TARGET)
	./$(TARGET) Test_Cases/test_input2.fx

.PHONY: all clean test