#include "../Header_Files/semantic_analyzer.hpp"
#include <iostream>
#include <algorithm>


std::unique_ptr<TypeNode> createType(TypeNode::TypeKind k) {
    return std::make_unique<TypeNode>(k);
}

// Helper to unwrap Type Aliases
TypeNode* resolveType(TypeNode* type, SymbolTable& symTab) {
    if (!type) return nullptr;
    if (type->kind == TypeNode::USER_DEFINED) {
        Symbol* sym = symTab.lookup(type->typeName);
        
        if (sym && sym->kind == SymbolKind::TYPE_NAME) {
            if (sym->type) {
                return resolveType(sym->type, symTab);
            }
        }
    }
    return type;
}

bool areTypesCompatible(TypeNode* target, TypeNode* source, SymbolTable& symTab) {
    if (!target || !source) return false;
    
    // 1. Resolve aliases to get underlying types
    TypeNode* tResolved = resolveType(target, symTab);
    TypeNode* sResolved = resolveType(source, symTab);

    // 2. Exact match check
    if (tResolved->kind == sResolved->kind) {
        if (tResolved->kind == TypeNode::USER_DEFINED) {
            return tResolved->typeName == sResolved->typeName;
        }
        return true;
    }

    // 3. Implicit Promotion: int -> real
    if (tResolved->kind == TypeNode::REAL && sResolved->kind == TypeNode::INT) {
        return true;
    }

    return false;
}

void reportError(int line, int col, const std::string& msg) {
    std::cerr << "\033[1;31mSemantic Error\033[0m at " << line << ":" << col << ": " << msg << "\n";
}

void DeclarationPass::visit(ProgramNode* node) {
    for (const auto& decl : node->declarations) {
        decl->accept(this);
    }
}

void DeclarationPass::visit(FunctionDefinitionNode* node) {
    // Store the entire function node in the symbol table so Pass 2 can check parameters
    if (!symTab.insert(node->declarator->name, SymbolKind::FUNCTION, node->returnType.get(), node, node->line, node->column)) {
        reportError(node->line, node->column, "Function '" + node->declarator->name + "' is already declared.");
    }
}

void DeclarationPass::visit(RecordDefinitionNode* node) {
    // Store the record definition so Pass 2 can check members
    if (!symTab.insert(node->name, SymbolKind::TYPE_NAME, nullptr, node, node->line, node->column)) {
        reportError(node->line, node->column, "Record '" + node->name + "' is already declared.");
    }
}

void DeclarationPass::visit(LabelDefinitionNode* node) {
    if (!symTab.insert(node->name, SymbolKind::TYPE_NAME, nullptr, node, node->line, node->column)) {
        reportError(node->line, node->column, "Label '" + node->name + "' is already declared.");
    }
    for (const auto& val : node->values) {
        if (!symTab.insert(val, SymbolKind::LABEL_VALUE, nullptr, nullptr, node->line, node->column)) {
            reportError(node->line, node->column, "Label Value '" + val + "' conflicts with another symbol.");
        }
    }
}

void DeclarationPass::visit(TypeAliasNode* node) {
    if (!symTab.insert(node->alias, SymbolKind::TYPE_NAME, node->originalType.get(), node, node->line, node->column)) {
        reportError(node->line, node->column, "Type Alias '" + node->alias + "' is already declared.");
    }
}

void DeclarationPass::visit(MacroDefinitionNode* node) {
    TypeNode* macroType = nullptr;
    
    if (LiteralNode* lit = dynamic_cast<LiteralNode*>(node->value.get())) {
        switch(lit->type) {
            case LiteralNode::INT: 
                macroType = new TypeNode(TypeNode::INT); 
                break;
            case LiteralNode::REAL: 
                macroType = new TypeNode(TypeNode::REAL); 
                break;
            case LiteralNode::BOOL: 
                macroType = new TypeNode(TypeNode::BOOL); 
                break;
            case LiteralNode::STRING: 
                macroType = new TypeNode(TypeNode::STRING); 
                break;
            default: 
                macroType = new TypeNode(TypeNode::VOID);
        }
    } else {
        macroType = new TypeNode(TypeNode::REAL); 
    }

    // Insert the Macro into the Symbol Table as a CONSTANT VARIABLE
    if (!symTab.insert(node->name, SymbolKind::VARIABLE, macroType, node, node->line, node->column)) {
        reportError(node->line, node->column, "Macro '" + node->name + "' is already defined.");
    }
}

void SemanticPass::visitChildren(const std::vector<std::unique_ptr<ASTNode>>& list) {
    for (const auto& node : list) {
        if (node) node->accept(this);
    }
}

void SemanticPass::visit(ProgramNode* node) {
    symTab.reset_to_root(); 
    visitChildren(node->declarations);
}

void SemanticPass::visit(FunctionDefinitionNode* node) {
    symTab.enter_scope();
    
    // CONTEXT: Save return type for checking RETURN statements inside body
    TypeNode* previousReturnType = currentFuncReturnType;
    currentFuncReturnType = node->returnType.get();

    // Register parameters
    for (const auto& param : node->declarator->parameters) {
        param->accept(this); 
    }

    if (node->body) {
        visitChildren(node->body->statements);
    }

    // Restore context
    currentFuncReturnType = previousReturnType;
    symTab.exit_scope();
}

void SemanticPass::visit(CompoundStatementNode* node) {
    symTab.enter_scope();
    visitChildren(node->statements);
    symTab.exit_scope();
}

void SemanticPass::visit(DeclarationNode* node) {
    for (const auto& decl : node->declarators) {
        if (decl.initializer) {
            decl.initializer->accept(this);
            if (decl.initializer->resolvedType) {
                if (!areTypesCompatible(node->type.get(), decl.initializer->resolvedType.get(), symTab)) {
                    std::string expected = node->type->typeKindToString(node->type->kind);
                    std::string actual = decl.initializer->resolvedType->typeKindToString(decl.initializer->resolvedType->kind);
                    reportError(node->line, node->column, 
                        "Type mismatch in initialization of '" + decl.declarator->name + 
                        "'. Expected " + expected + ", got " + actual);
                }
            }
        }
        if (!symTab.insert(decl.declarator->name, SymbolKind::VARIABLE, node->type.get(), node, node->line, node->column)) {
            reportError(node->line, node->column, "Variable '" + decl.declarator->name + "' redeclared in this scope.");
        }
    }
}

void SemanticPass::visit(ParameterNode* node) {
    if (!symTab.insert(node->declarator->name, SymbolKind::PARAMETER, node->type.get(), node, node->line, node->column)) {
        reportError(node->line, node->column, "Parameter '" + node->declarator->name + "' redeclared.");
    }
}

void SemanticPass::visit(IdentifierNode* node) {
    Symbol* sym = symTab.lookup(node->name);
    if (!sym) {
        reportError(node->line, node->column, "Undeclared identifier '" + node->name + "'");
        node->resolvedType = createType(TypeNode::VOID); 
    } else {
        if (sym->kind == SymbolKind::TYPE_NAME) {
            node->resolvedType = createType(TypeNode::USER_DEFINED);
            node->resolvedType->typeName = sym->name;
        }
        else if (sym->type) {
            node->resolvedType = std::make_unique<TypeNode>(*sym->type);
        } 
        else {
            node->resolvedType = createType(TypeNode::VOID);
        }
    }
}

void SemanticPass::visit(LiteralNode* node) {
    switch(node->type) {
        case LiteralNode::INT: node->resolvedType = createType(TypeNode::INT); break;
        case LiteralNode::REAL: node->resolvedType = createType(TypeNode::REAL); break;
        case LiteralNode::STRING: node->resolvedType = createType(TypeNode::STRING); break;
        case LiteralNode::BOOL: node->resolvedType = createType(TypeNode::BOOL); break;
        case LiteralNode::AMOUNT: node->resolvedType = createType(TypeNode::AMOUNT); break;
        case LiteralNode::DATETIME: node->resolvedType = createType(TypeNode::DATETIME); break;
        case LiteralNode::CHAR: node->resolvedType = createType(TypeNode::CHAR); break;
        default: node->resolvedType = createType(TypeNode::VOID);
    }
}

void SemanticPass::visit(FunctionCallNode* node) {
    node->function->accept(this);

    IdentifierNode* funcId = dynamic_cast<IdentifierNode*>(node->function.get());
    if (!funcId) {
        reportError(node->line, node->column, "Complex function calls not supported yet.");
        node->resolvedType = createType(TypeNode::VOID);
        return;
    }

    Symbol* sym = symTab.lookup(funcId->name);
    if (!sym || sym->kind != SymbolKind::FUNCTION) {
        reportError(node->line, node->column, "Call to undefined function '" + funcId->name + "'");
        node->resolvedType = createType(TypeNode::VOID);
        return;
    }

    FunctionDefinitionNode* funcDef = dynamic_cast<FunctionDefinitionNode*>(sym->definition);
    if (!funcDef) {
        node->resolvedType = std::make_unique<TypeNode>(*sym->type); 
        return; 
    }

    size_t paramCount = funcDef->declarator->parameters.size();
    size_t argCount = node->arguments.size();

    if (argCount != paramCount) {
        reportError(node->line, node->column, 
            "Incorrect argument count for function '" + funcId->name + 
            "'. Expected " + std::to_string(paramCount) + ", got " + std::to_string(argCount));
    }

    size_t limit = std::min(argCount, paramCount);
    for (size_t i = 0; i < limit; ++i) {
        node->arguments[i]->accept(this); // Resolve argument type
        
        ParameterNode* param = funcDef->declarator->parameters[i].get();
        if (param->isModifiable) {
            bool isLValue = (dynamic_cast<IdentifierNode*>(node->arguments[i].get()) != nullptr) ||
                            (dynamic_cast<MemberAccessNode*>(node->arguments[i].get()) != nullptr) ||
                            (dynamic_cast<SubscriptNode*>(node->arguments[i].get()) != nullptr);
            if (!isLValue) {
                reportError(node->arguments[i]->line, node->arguments[i]->column, 
                    "Argument " + std::to_string(i+1) + " passed to function '" + funcId->name + 
                    "' must be a variable (L-Value) because the parameter is marked 'modifiable'.");
            }
        }
        if (node->arguments[i]->resolvedType && param->type) {
            if (!areTypesCompatible(param->type.get(), node->arguments[i]->resolvedType.get(), symTab)) {
                 std::string pType = param->type->typeKindToString(param->type->kind);
                 std::string aType = node->arguments[i]->resolvedType->typeKindToString(node->arguments[i]->resolvedType->kind);
                 reportError(node->arguments[i]->line, node->arguments[i]->column, 
                    "Type mismatch for argument " + std::to_string(i+1) + 
                    " in call to '" + funcId->name + "'. Expected " + pType + ", got " + aType);
            }
        }
    }

    if (funcDef->returnType) {
        node->resolvedType = std::make_unique<TypeNode>(*funcDef->returnType);
    } else {
        node->resolvedType = createType(TypeNode::VOID);
    }
}

void SemanticPass::visit(MemberAccessNode* node) {
    // 1. Resolve the object (LHS)
    if (node->object) node->object->accept(this);
    
    if (!node->object->resolvedType) {
        node->resolvedType = createType(TypeNode::VOID);
        return;
    }

    TypeNode* objType = node->object->resolvedType.get();

    // 2. Ensure it is a USER_DEFINED type
    if (objType->kind != TypeNode::USER_DEFINED) {
        reportError(node->line, node->column, "Member access requested on non-user-defined type.");
        node->resolvedType = createType(TypeNode::VOID);
        return;
    }

    // 3. Lookup the Definition (Could be Record OR Label)
    Symbol* typeSym = symTab.lookup(objType->typeName);
    if (!typeSym || !typeSym->definition) {
        reportError(node->line, node->column, "Undefined type '" + objType->typeName + "'");
        node->resolvedType = createType(TypeNode::VOID);
        return;
    }

    // CASE A: Label (Enum) Access
    if (LabelDefinitionNode* labelDef = dynamic_cast<LabelDefinitionNode*>(typeSym->definition)) {
        if (node->accessType != MemberAccessNode::DOUBLE_COLON) {
             reportError(node->line, node->column, "Use '::' to access label values.");
        }

        bool found = false;
        for(const auto& val : labelDef->values) {
            if (val == node->member) {
                found = true; 
                break;
            }
        }

        if (found) {
            // The type of "Signal::BUY" is "Signal"
            node->resolvedType = std::make_unique<TypeNode>(objType->typeName);
        } else {
            reportError(node->line, node->column, "Label '" + objType->typeName + "' has no value '" + node->member + "'");
            node->resolvedType = createType(TypeNode::VOID);
        }
        return; 
    }

    // CASE B: Record Member Access
    if (RecordDefinitionNode* recDef = dynamic_cast<RecordDefinitionNode*>(typeSym->definition)) {
        
        if (node->accessType != MemberAccessNode::ARROW) {
             reportError(node->line, node->column, "Use '->' to access record members.");
        }

        bool memberFound = false;
        for (const auto& member : recDef->members) {
            DeclarationNode* decl = dynamic_cast<DeclarationNode*>(member.get());
            if (decl) {
                for (const auto& d : decl->declarators) {
                    if (d.declarator->name == node->member) {
                        if (decl->type) {
                            node->resolvedType = std::make_unique<TypeNode>(*decl->type);
                        }
                        memberFound = true;
                        break;
                    }
                }
            }
            if (memberFound) break;
        }

        if (!memberFound) {
            reportError(node->line, node->column, "Record '" + objType->typeName + "' has no member named '" + node->member + "'");
            node->resolvedType = createType(TypeNode::VOID);
        }
        return;
    }

    reportError(node->line, node->column, "Type '" + objType->typeName + "' does not support member access.");
    node->resolvedType = createType(TypeNode::VOID);
}

void SemanticPass::visit(BinaryOpNode* node) {
    if (node->left) node->left->accept(this);
    if (node->right) node->right->accept(this);

    if (!node->left->resolvedType || !node->right->resolvedType) return;

    TypeNode* lResolved = resolveType(node->left->resolvedType.get(), symTab);
    TypeNode* rResolved = resolveType(node->right->resolvedType.get(), symTab);
    
    TypeNode::TypeKind lKind = lResolved->kind;
    TypeNode::TypeKind rKind = rResolved->kind;

    if (node->op >= BinaryOpNode::EQ && node->op <= BinaryOpNode::OR) {
         node->resolvedType = createType(TypeNode::BOOL);
         return;
    }
    
    if (lKind == TypeNode::INT && rKind == TypeNode::INT) {
        node->resolvedType = createType(TypeNode::INT);
    } 
    else if ((lKind == TypeNode::INT && rKind == TypeNode::REAL) || 
             (lKind == TypeNode::REAL && rKind == TypeNode::INT) || 
             (lKind == TypeNode::REAL && rKind == TypeNode::REAL)) {
        node->resolvedType = createType(TypeNode::REAL);
    }
    else if (lKind == TypeNode::STRING && rKind == TypeNode::STRING && node->op == BinaryOpNode::ADD) {
        node->resolvedType = createType(TypeNode::STRING);
    }
    else {
         reportError(node->line, node->column, 
            "Invalid binary operation '" + node->opToString(node->op) + 
            "' between " + node->left->resolvedType->typeKindToString(lKind) + 
            " and " + node->right->resolvedType->typeKindToString(rKind));
         node->resolvedType = createType(TypeNode::VOID);
    }
}

void SemanticPass::visit(AssignmentNode* node) {
    if (node->lhs) node->lhs->accept(this);
    if (node->rhs) node->rhs->accept(this);

    if (!node->lhs->resolvedType || !node->rhs->resolvedType) return;

    if (!areTypesCompatible(node->lhs->resolvedType.get(), node->rhs->resolvedType.get(), symTab)) {
        std::string lType = node->lhs->resolvedType->typeKindToString(node->lhs->resolvedType->kind);
        std::string rType = node->rhs->resolvedType->typeKindToString(node->rhs->resolvedType->kind);
        
        reportError(node->line, node->column, 
            "Cannot assign value of type " + rType + " to variable of type " + lType);
    }
    node->resolvedType = std::make_unique<TypeNode>(*node->lhs->resolvedType);
}

void SemanticPass::visit(JumpStatementNode* node) {
    if (node->jumpType == JumpStatementNode::BREAK || node->jumpType == JumpStatementNode::CONTINUE) {
        if (loopDepth == 0) {
            reportError(node->line, node->column, "Break/Continue statement found outside of loop.");
        }
    }
    if (node->jumpType == JumpStatementNode::RETURN) {
        if (node->returnValue) {
            node->returnValue->accept(this);
            
            if (currentFuncReturnType) {
                if (currentFuncReturnType->kind == TypeNode::VOID) {
                    reportError(node->line, node->column, "Void function should not return a value.");
                }
                else if (node->returnValue->resolvedType && 
                        !areTypesCompatible(currentFuncReturnType, node->returnValue->resolvedType.get(), symTab)) {
                    
                    std::string expected = currentFuncReturnType->typeKindToString(currentFuncReturnType->kind);
                    std::string actual = node->returnValue->resolvedType->typeKindToString(node->returnValue->resolvedType->kind);
                    
                    reportError(node->line, node->column, 
                        "Return type mismatch. Expected " + expected + ", got " + actual);
                }
            }
        } else {
            // Return void
            if (currentFuncReturnType && currentFuncReturnType->kind != TypeNode::VOID) {
                std::string expected = currentFuncReturnType->typeKindToString(currentFuncReturnType->kind);
                reportError(node->line, node->column, "Non-void function must return a value of type " + expected);
            }
        }
    }
}

void SemanticPass::visit(IfStatementNode* node) {
    if (node->condition) node->condition->accept(this);
    if (node->thenBranch) node->thenBranch->accept(this);
    if (node->elseBranch) node->elseBranch->accept(this);
}

void SemanticPass::visit(WhileStatementNode* node) {
    loopDepth++;

    if (node->condition) {
        node->condition->accept(this);
        if (node->condition->resolvedType && node->condition->resolvedType->kind != TypeNode::BOOL) {
            reportError(node->line, node->column, "While-loop condition must be of type bool.");
        }
    }
    
    if (node->body) node->body->accept(this);

    loopDepth--;
}

void SemanticPass::visit(ForStatementNode* node) {
    loopDepth++;
    if (node->forType == ForStatementNode::FINEX_RANGE || node->forType == ForStatementNode::FOR_IN) {
        symTab.enter_scope();
        if (!symTab.insert(node->varName, SymbolKind::VARIABLE, node->varType.get(), node, node->line, node->column)) {
             reportError(node->line, node->column, "Loop variable '" + node->varName + "' conflicts with existing symbol");
        }
        if (node->startExpr) node->startExpr->accept(this);
        if (node->endExpr) node->endExpr->accept(this);
        if (node->stepExpr) node->stepExpr->accept(this);
        if (node->collection) node->collection->accept(this);
        if (node->body) node->body->accept(this);
        symTab.exit_scope();
    } else {
        symTab.enter_scope();
        if (node->init) node->init->accept(this);
        if (node->condition) node->condition->accept(this);
        if (node->update) node->update->accept(this);
        if (node->body) node->body->accept(this);
        symTab.exit_scope();
    }
    loopDepth--;
}

void SemanticPass::visit(ExpressionStatementNode* node) { if (node->expression) node->expression->accept(this); }
void SemanticPass::visit(TryCatchStatementNode* node) { 
    if (node->tryBlock) node->tryBlock->accept(this);
    if (node->catchBlock) node->catchBlock->accept(this);
}
void SemanticPass::visit(CheckStatementNode* node) { if (node->condition) node->condition->accept(this); }
void SemanticPass::visit(UnaryOpNode* node) { 
    if (node->operand) {
        node->operand->accept(this);
        if (node->operand->resolvedType) 
            node->resolvedType = std::make_unique<TypeNode>(*node->operand->resolvedType);
    }
}
void SemanticPass::visit(CastNode* node) { 
    if (node->expression) node->expression->accept(this);
    if (node->targetType) node->resolvedType = std::make_unique<TypeNode>(*node->targetType);
}
void SemanticPass::visit(SubscriptNode* node) { 
    if (node->array) node->array->accept(this); 
    if (node->index) node->index->accept(this); 
    if (node->index->resolvedType->kind != TypeNode::INT) {
        reportError(node->line, node->column, "Array index must be an integer.");
    }
    if (node->array->resolvedType) {
        TypeNode* arrType = resolveType(node->array->resolvedType.get(), symTab);
        
        if (!arrType->genericArgs.empty()) {
            node->resolvedType = std::make_unique<TypeNode>(*arrType->genericArgs[0]);
        } else {
             reportError(node->line, node->column, "Subscript operator used on non-generic/non-list type.");
             node->resolvedType = createType(TypeNode::VOID);
        }
    }
}
void SemanticPass::visit(InitializerListNode* node) { 
    for(auto& e : node->elements) e->accept(this); 
}