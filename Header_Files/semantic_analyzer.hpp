#ifndef SEMANTIC_ANALYZER_HPP
#define SEMANTIC_ANALYZER_HPP

#include "ast.hpp"
#include "symbol_table.hpp"
#include <vector>
#include <memory>

class StubVisitor : public ASTVisitor {
public:
    void visit(TypeNode* node) override {}
    void visit(BinaryOpNode* node) override {}
    void visit(UnaryOpNode* node) override {}
    void visit(AssignmentNode* node) override {}
    void visit(CastNode* node) override {}
    void visit(IdentifierNode* node) override {}
    void visit(LiteralNode* node) override {}
    void visit(FunctionCallNode* node) override {}
    void visit(MemberAccessNode* node) override {}
    void visit(SubscriptNode* node) override {}
    void visit(InitializerListNode* node) override {}
    void visit(CompoundStatementNode* node) override {}
    void visit(ExpressionStatementNode* node) override {}
    void visit(IfStatementNode* node) override {}
    void visit(WhileStatementNode* node) override {}
    void visit(ForStatementNode* node) override {}
    void visit(JumpStatementNode* node) override {}
    void visit(TryCatchStatementNode* node) override {}
    void visit(CheckStatementNode* node) override {}
    void visit(DeclaratorNode* node) override {}
    void visit(ParameterNode* node) override {}
    void visit(DeclarationNode* node) override {}
    void visit(FunctionDefinitionNode* node) override {}
    void visit(RecordDefinitionNode* node) override {}
    void visit(LabelDefinitionNode* node) override {}
    void visit(ImportStatementNode* node) override {}
    void visit(MacroDefinitionNode* node) override {}
    void visit(TypeAliasNode* node) override {}
    void visit(ProgramNode* node) override {}
};

class DeclarationPass : public StubVisitor {
    SymbolTable& symTab;
public:
    DeclarationPass(SymbolTable& st) : symTab(st) {}

    void visit(ProgramNode* node) override;
    void visit(FunctionDefinitionNode* node) override;
    void visit(RecordDefinitionNode* node) override;
    void visit(LabelDefinitionNode* node) override;
    void visit(TypeAliasNode* node) override;
};

class SemanticPass : public StubVisitor {
    SymbolTable& symTab;
    TypeNode* currentFuncReturnType = nullptr; 

public:
    SemanticPass(SymbolTable& st) : symTab(st) {}

    void visit(ProgramNode* node) override;
    void visit(FunctionDefinitionNode* node) override;
    void visit(CompoundStatementNode* node) override;
    void visit(DeclarationNode* node) override;
    void visit(ParameterNode* node) override;
    void visit(IdentifierNode* node) override;
    void visit(LiteralNode* node) override;
    void visit(IfStatementNode* node) override;
    void visit(WhileStatementNode* node) override;
    void visit(ExpressionStatementNode* node) override;
    void visit(AssignmentNode* node) override;
    void visit(BinaryOpNode* node) override;
    void visit(JumpStatementNode* node) override; 
    void visit(ForStatementNode* node) override;
    void visit(TryCatchStatementNode* node) override;
    void visit(CheckStatementNode* node) override;
    void visit(UnaryOpNode* node) override;
    void visit(FunctionCallNode* node) override;
    void visit(MemberAccessNode* node) override;
    void visit(CastNode* node) override;
    void visit(SubscriptNode* node) override;
    void visit(InitializerListNode* node) override;
   
    // Helper
    void visitChildren(const std::vector<std::unique_ptr<ASTNode>>& list);
};

#endif // SEMANTIC_ANALYZER_HPP