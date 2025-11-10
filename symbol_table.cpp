#include "symbol_table.hpp"
#include <iostream>

// Symbol Constructor Implementation
Symbol::Symbol(std::string n, SymbolKind k, TypeNode* t, ASTNode* def, int l, int c)
    : name(n), kind(k), type(t), definition(def), line(l), column(c) {}

// Scope Implementation
Scope::Scope(int scope_id, Scope* p) : id(scope_id), parent(p) {}

bool Scope::define(const Symbol& sym) {
    if (symbols.find(sym.name) != symbols.end()) {
        return false; 
    }
    symbols.insert({sym.name, sym});
    return true;
}

Symbol* Scope::resolve(const std::string& name) {
    auto it = symbols.find(name);
    if (it != symbols.end()) return &it->second;
    if (parent) return parent->resolve(name);
    return nullptr;
}

Symbol* Scope::resolve_local(const std::string& name) {
    auto it = symbols.find(name);
    if (it != symbols.end()) return &it->second;
    return nullptr;
}

// SymbolTable Implementation
SymbolTable::SymbolTable() {
    std::cout << "[SymbolTable] Initializing Global Scope (ID: 0)" << std::endl;
    root = std::make_unique<Scope>(0, nullptr);
    current = root.get();
    next_scope_id = 1;
}

void SymbolTable::enter_scope() {
    int new_id = next_scope_id++;
    std::cout << "[SymbolTable] Entering new Scope ID: " << new_id 
              << " (Parent ID: " << current->id << ")" << std::endl;
    
    auto new_scope = std::make_unique<Scope>(new_id, current);
    Scope* raw_ptr = new_scope.get();
    current->children.push_back(std::move(new_scope));
    current = raw_ptr;
}

void SymbolTable::exit_scope() {
    if (current->parent) {
        std::cout << "[SymbolTable] Exiting Scope ID: " << current->id 
                  << " -> Returning to Scope ID: " << current->parent->id << std::endl;
        current = current->parent;
    } else {
        std::cerr << "[SymbolTable] Error: Cannot exit global scope!" << std::endl;
    }
}

void SymbolTable::reset_to_root() {
    std::cout << "[SymbolTable] Resetting cursor to Global Scope" << std::endl;
    current = root.get();
}

bool SymbolTable::insert(const std::string& name, SymbolKind kind, TypeNode* type, ASTNode* def, int line, int col) {
    std::cout << "[SymbolTable] Inserting '" << name << "' (" << kind_to_string(kind) 
              << ") into Scope ID: " << current->id 
              << " [L:" << line << ", C:" << col << "] ... ";
    
    Symbol sym(name, kind, type, def, line, col);
    bool success = current->define(sym);
    
    if (success) std::cout << "Success." << std::endl;
    else std::cout << "Failed (Already Exists)." << std::endl;
    
    return success;
}

Symbol* SymbolTable::lookup(const std::string& name) {
    Symbol* s = current->resolve(name);
    return s;
}

bool SymbolTable::is_declared_locally(const std::string& name) {
    return current->resolve_local(name) != nullptr;
}

void SymbolTable::print_table() const {
    std::cout << "\n=== SYMBOL TABLE DUMP ===\n";
    print_scope(root.get(), 0);
    std::cout << "=========================\n";
}

void SymbolTable::print_scope(Scope* sc, int indent) const {
    std::string pad(indent * 2, ' ');
    std::cout << pad << "Scope " << sc->id << (sc->parent ? "" : " (Global)") << ":\n";
    
    for (const auto& pair : sc->symbols) {
        const Symbol& s = pair.second;
        std::cout << pad << "  - " << s.name << " [" << kind_to_string(s.kind) << "]";
        std::cout << " @" << s.line << ":" << s.column;
        if (s.type) {
            std::cout << " type: ";
            if (s.type->kind == TypeNode::USER_DEFINED) std::cout << s.type->typeName;
            else std::cout << "primitive";
        }
        std::cout << "\n";
    }

    for (const auto& child : sc->children) {
        print_scope(child.get(), indent + 1);
    }
}

std::string SymbolTable::kind_to_string(SymbolKind k) const {
    switch(k) {
        case SymbolKind::VARIABLE: return "Var";
        case SymbolKind::FUNCTION: return "Func";
        case SymbolKind::PARAMETER: return "Param";
        case SymbolKind::TYPE_NAME: return "Type";
        case SymbolKind::LABEL_VALUE: return "LabelVal";
        default: return "Unknown";
    }
}