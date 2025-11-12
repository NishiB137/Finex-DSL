#include "semantic_analyzer.hpp"
#include <iostream>

// pass 1

void DeclarationPass::visit(ProgramNode* node) {
    for (const auto& decl : node->declarations) {
        decl->accept(this);
    }
}

void DeclarationPass::visit(FunctionDefinitionNode* node) {
    // Register the function name in the Global Scope
    if (!symTab.insert(node->declarator->name, SymbolKind::FUNCTION, node->returnType.get(), node, node->line, node->column)) {
        std::cerr << "Error at " << node->line << ":" << node->column 
                  << ": Function '" << node->declarator->name << "' is already declared.\n";
    }
}

void DeclarationPass::visit(RecordDefinitionNode* node) {
    if (!symTab.insert(node->name, SymbolKind::TYPE_NAME, nullptr, node, node->line, node->column)) {
        std::cerr << "Error at " << node->line << ":" << node->column 
                  << ": Record '" << node->name << "' is already declared.\n";
    }
}

void DeclarationPass::visit(LabelDefinitionNode* node) {
    if (!symTab.insert(node->name, SymbolKind::TYPE_NAME, nullptr, node, node->line, node->column)) {
        std::cerr << "Error at " << node->line << ":" << node->column 
                  << ": Label '" << node->name << "' is already declared.\n";
    }
    for (const auto& val : node->values) {
        // Values are strings, not nodes, so we use the LabelDefinitionNode's location
        if (!symTab.insert(val, SymbolKind::LABEL_VALUE, nullptr, nullptr, node->line, node->column)) {
            std::cerr << "Error at " << node->line << ":" << node->column 
                      << ": Label Value '" << val << "' conflicts with another symbol.\n";
        }
    }
}

void DeclarationPass::visit(TypeAliasNode* node) {
    if (!symTab.insert(node->alias, SymbolKind::TYPE_NAME, node->originalType.get(), node, node->line, node->column)) {
        std::cerr << "Error at " << node->line << ":" << node->column 
                  << ": Type Alias '" << node->alias << "' is already declared.\n";
    }
}

// implementation

void SemanticPass::visitChildren(const std::vector<std::unique_ptr<ASTNode>>& list) {
    for (const auto& node : list) {
        node->accept(this);
    }
}

void SemanticPass::visit(ProgramNode* node) {
    symTab.reset_to_root(); 
    visitChildren(node->declarations);
}

void SemanticPass::visit(FunctionDefinitionNode* node) {
    symTab.enter_scope();
    
    // Register parameters
    for (const auto& param : node->declarator->parameters) {
        param->accept(this); 
    }

    // Visit body
    if (node->body) {
        visitChildren(node->body->statements);
    }

    symTab.exit_scope();
}

void SemanticPass::visit(CompoundStatementNode* node) {
    symTab.enter_scope();
    visitChildren(node->statements);
    symTab.exit_scope();
}

void SemanticPass::visit(DeclarationNode* node) {
    for (const auto& decl : node->declarators) {
        if (!symTab.insert(decl.declarator->name, SymbolKind::VARIABLE, node->type.get(), node, node->line, node->column)) {
            std::cerr << "Error at " << node->line << ":" << node->column 
                      << ": Variable '" << decl.declarator->name << "' redeclared in this scope.\n";
        }
        if (decl.initializer) {
            decl.initializer->accept(this);
        }
    }
}

void SemanticPass::visit(ParameterNode* node) {
    if (!symTab.insert(node->declarator->name, SymbolKind::PARAMETER, node->type.get(), node, node->line, node->column)) {
        std::cerr << "Error at " << node->line << ":" << node->column 
                  << ": Parameter '" << node->declarator->name << "' redeclared.\n";
    }
}

void SemanticPass::visit(IdentifierNode* node) {
    Symbol* sym = symTab.lookup(node->name);
    if (!sym) {
        std::cerr << "Error at " << node->line << ":" << node->column 
                  << ": Undeclared identifier '" << node->name << "'\n";
    } 
}

// control flow visitor implementation

void SemanticPass::visit(IfStatementNode* node) {
    if (node->condition) node->condition->accept(this);
    if (node->thenBranch) node->thenBranch->accept(this);
    if (node->elseBranch) node->elseBranch->accept(this);
}

void SemanticPass::visit(WhileStatementNode* node) {
    if (node->condition) node->condition->accept(this);
    if (node->body) node->body->accept(this);
}

void SemanticPass::visit(ForStatementNode* node) {
    if (node->forType == ForStatementNode::FINEX_RANGE || 
        node->forType == ForStatementNode::FOR_IN) {
        symTab.enter_scope(); 
        
        // Insert loop variable
        if (!symTab.insert(node->varName, SymbolKind::VARIABLE, 
                          node->varType.get(), node, node->line, node->column)) {
            std::cerr << "Error at " << node->line << ":" << node->column 
                      << ": Loop variable '" << node->varName << "' conflicts with existing symbol\n";
        }
        
        // Visit range expressions
        if (node->startExpr) node->startExpr->accept(this);
        if (node->endExpr) node->endExpr->accept(this);
        if (node->stepExpr) node->stepExpr->accept(this);
        if (node->collection) node->collection->accept(this);
        
        if (node->body) node->body->accept(this);
        
        symTab.exit_scope();
    } else {
        // C-Style For
        if (node->init) node->init->accept(this);
        if (node->condition) node->condition->accept(this);
        if (node->update) node->update->accept(this);
        if (node->body) node->body->accept(this);
    }
}

void SemanticPass::visit(JumpStatementNode* node) {
    if (node->returnValue) {
        node->returnValue->accept(this);
    }
}

void SemanticPass::visit(ExpressionStatementNode* node) {
    if (node->expression) {
        node->expression->accept(this);
    }
}

void SemanticPass::visit(TryCatchStatementNode* node) {
    if (node->tryBlock) node->tryBlock->accept(this);
    
    if (node->catchBlock) {
        symTab.enter_scope(); // Manual scope for catch
        
        if (!node->exceptionVar.empty()) {
            if (!symTab.insert(node->exceptionVar, SymbolKind::VARIABLE,
                              node->exceptionType.get(), node, node->line, node->column)) {
                std::cerr << "Error at " << node->line << ":" << node->column 
                          << ": Exception variable '" << node->exceptionVar << "' redeclared\n";
            }
        }
        
        visitChildren(node->catchBlock->statements);
        symTab.exit_scope();
    }
}

void SemanticPass::visit(CheckStatementNode* node) {
    if (node->condition) node->condition->accept(this);
}

// expression visitor implementation

void SemanticPass::visit(BinaryOpNode* node) {
    if (node->left) node->left->accept(this);
    if (node->right) node->right->accept(this);
}

void SemanticPass::visit(AssignmentNode* node) {
    if (node->lhs) node->lhs->accept(this);
    if (node->rhs) node->rhs->accept(this);
}

void SemanticPass::visit(UnaryOpNode* node) {
    if (node->operand) node->operand->accept(this);
}

void SemanticPass::visit(FunctionCallNode* node) {
    if (node->function) node->function->accept(this);
    for (const auto& arg : node->arguments) {
        arg->accept(this);
    }
}

void SemanticPass::visit(CastNode* node) {
    if (node->expression) node->expression->accept(this);
}

void SemanticPass::visit(MemberAccessNode* node) {
    if (node->object) node->object->accept(this);
}

void SemanticPass::visit(SubscriptNode* node) {
    if (node->array) node->array->accept(this);
    if (node->index) node->index->accept(this);
}

void SemanticPass::visit(InitializerListNode* node) {
    for (const auto& elem : node->elements) {
        elem->accept(this);
    }
}