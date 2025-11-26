#ifndef SYMBOL_TABLE_HPP
#define SYMBOL_TABLE_HPP

#include <string>
#include <unordered_map>
#include <vector>
#include <memory>
#include "ast.hpp"

enum class SymbolKind {
    VARIABLE,
    FUNCTION,
    PARAMETER,
    TYPE_NAME,
    LABEL_VALUE
};

struct Symbol {
    std::string name;
    SymbolKind kind;
    TypeNode* type;
    ASTNode* definition;
    int line;  
    int column; 
    
    // Declaration ONLY (No body here)
    Symbol(std::string n, SymbolKind k, TypeNode* t = nullptr, 
           ASTNode* def = nullptr, int l = 0, int c = 0);
};

class Scope {
public:
    int id;
    Scope* parent;
    std::unordered_map<std::string, Symbol> symbols;
    std::vector<std::unique_ptr<Scope>> children;

    Scope(int scope_id, Scope* p = nullptr);
    
    bool define(const Symbol& sym);
    Symbol* resolve(const std::string& name);
    Symbol* resolve_local(const std::string& name);
};

class SymbolTable {
public:
    SymbolTable();

    // Scope Management
    void enter_scope();
    void exit_scope();
    void reset_to_root();

    // Symbol Operations
    bool insert(const std::string& name, SymbolKind kind, TypeNode* type = nullptr, ASTNode* def = nullptr, int line = 0, int col = 0);
    
    Symbol* lookup(const std::string& name);
    bool is_declared_locally(const std::string& name);

    // Debugging
    void print_table() const;

private:
    std::unique_ptr<Scope> root;
    Scope* current;
    int next_scope_id;

    void print_scope(Scope* sc, int indent) const;
    std::string kind_to_string(SymbolKind k) const;
};

#endif // SYMBOL_TABLE_HPP