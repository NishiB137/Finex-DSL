#ifndef AST_HPP
#define AST_HPP

#include <string>
#include <vector>
#include <memory>
#include <iostream>

class ASTVisitor;

class ASTNode {
public:
    int line = 0;    
    int column = 0;  

    virtual ~ASTNode() = default;
    virtual void print(int indent = 0) const = 0;
    virtual void accept(ASTVisitor* visitor) = 0;
protected:
    void printIndent(int indent) const {
        for(int i = 0; i < indent; i++) std::cout << "  ";
    }
};

class TypeNode : public ASTNode {
public:
    enum TypeKind {
        INT, REAL, CHAR, STRING, BOOL, DATETIME, AMOUNT, VOID,
        USER_DEFINED, GENERIC
    };
    
    TypeKind kind;
    std::string typeName;
    std::vector<std::unique_ptr<TypeNode>> genericArgs;
    
    TypeNode(TypeKind k) : kind(k) {}
    TypeNode(const std::string& name) : kind(USER_DEFINED), typeName(name) {}

    TypeNode(const TypeNode& other) : kind(other.kind), typeName(other.typeName) {
        for (const auto& arg : other.genericArgs) {
            genericArgs.push_back(std::make_unique<TypeNode>(*arg));
        }
    }

    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;

    std::string typeKindToString(TypeKind k) const;
};

class ExpressionNode : public ASTNode {
public:
    std::unique_ptr<TypeNode> resolvedType = nullptr;

    virtual ~ExpressionNode() = default;
};

class BinaryOpNode : public ExpressionNode {
public:
    enum OpType {
        ADD, SUB, MUL, DIV, INT_DIV, MOD, POW,
        EQ, NEQ, TEQ, GT, LT, GEQ, LEQ,
        AND, OR, IN, COMMA
    };
    
    OpType op;
    std::unique_ptr<ExpressionNode> left;
    std::unique_ptr<ExpressionNode> right;
    
    BinaryOpNode(OpType o, std::unique_ptr<ExpressionNode> l, 
                 std::unique_ptr<ExpressionNode> r)
        : op(o), left(std::move(l)), right(std::move(r)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
    
    std::string opToString(OpType o) const;
};

class UnaryOpNode : public ExpressionNode {
public:
    enum OpType { PLUS, MINUS, NOT };
    
    OpType op;
    std::unique_ptr<ExpressionNode> operand;
    
    UnaryOpNode(OpType o, std::unique_ptr<ExpressionNode> operand)
        : op(o), operand(std::move(operand)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
    
private:
    std::string opToString(OpType o) const;
};

class AssignmentNode : public ExpressionNode {
public:
    enum OpType { 
        ASSIGN, PLUS_ASSIGN, MINUS_ASSIGN, MULT_ASSIGN, 
        DIV_ASSIGN, INT_DIV_ASSIGN, MOD_ASSIGN, POWER_ASSIGN 
    };
    
    OpType op;
    std::unique_ptr<ExpressionNode> lhs;
    std::unique_ptr<ExpressionNode> rhs;
    
    AssignmentNode(OpType o, std::unique_ptr<ExpressionNode> l,
                   std::unique_ptr<ExpressionNode> r)
        : op(o), lhs(std::move(l)), rhs(std::move(r)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
    
private:
    std::string opToString(OpType o) const;
};

class CastNode : public ExpressionNode {
public:
    std::unique_ptr<TypeNode> targetType;
    std::unique_ptr<ExpressionNode> expression;
    
    CastNode(std::unique_ptr<TypeNode> type, std::unique_ptr<ExpressionNode> expr)
        : targetType(std::move(type)), expression(std::move(expr)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class IdentifierNode : public ExpressionNode {
public:
    std::string name;
    
    IdentifierNode(const std::string& n) : name(n) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class LiteralNode : public ExpressionNode {
public:
    enum LiteralType { INT, REAL, STRING, CHAR, BOOL, AMOUNT, DATETIME };
    
    LiteralType type;
    std::string value;
    
    LiteralNode(LiteralType t, const std::string& v) : type(t), value(v) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;

    std::string typeToString(LiteralType t) const;
};

class FunctionCallNode : public ExpressionNode {
public:
    std::unique_ptr<ExpressionNode> function;
    std::vector<std::unique_ptr<ExpressionNode>> arguments;
    
    FunctionCallNode(std::unique_ptr<ExpressionNode> func)
        : function(std::move(func)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class MemberAccessNode : public ExpressionNode {
public:
    enum AccessType { ARROW, DOUBLE_COLON };
    
    AccessType accessType;
    std::unique_ptr<ExpressionNode> object;
    std::string member;
    
    MemberAccessNode(AccessType type, std::unique_ptr<ExpressionNode> obj, 
                     const std::string& mem)
        : accessType(type), object(std::move(obj)), member(mem) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class SubscriptNode : public ExpressionNode {
public:
    std::unique_ptr<ExpressionNode> array;
    std::unique_ptr<ExpressionNode> index;
    
    SubscriptNode(std::unique_ptr<ExpressionNode> arr, 
                  std::unique_ptr<ExpressionNode> idx)
        : array(std::move(arr)), index(std::move(idx)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class InitializerListNode : public ExpressionNode {
public:
    std::vector<std::unique_ptr<ExpressionNode>> elements;
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class StatementNode : public ASTNode {
public:
    virtual ~StatementNode() = default;
};

class CompoundStatementNode : public StatementNode {
public:
    std::vector<std::unique_ptr<ASTNode>> statements;
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class ExpressionStatementNode : public StatementNode {
public:
    std::unique_ptr<ExpressionNode> expression;
    
    ExpressionStatementNode(std::unique_ptr<ExpressionNode> expr = nullptr)
        : expression(std::move(expr)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class IfStatementNode : public StatementNode {
public:
    std::unique_ptr<ExpressionNode> condition;
    std::unique_ptr<StatementNode> thenBranch;
    std::unique_ptr<StatementNode> elseBranch;
    
    IfStatementNode(std::unique_ptr<ExpressionNode> cond,
                    std::unique_ptr<StatementNode> thenBr,
                    std::unique_ptr<StatementNode> elseBr = nullptr)
        : condition(std::move(cond)), thenBranch(std::move(thenBr)),
          elseBranch(std::move(elseBr)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class WhileStatementNode : public StatementNode {
public:
    std::unique_ptr<ExpressionNode> condition;
    std::unique_ptr<StatementNode> body;
    
    WhileStatementNode(std::unique_ptr<ExpressionNode> cond,
                       std::unique_ptr<StatementNode> b)
        : condition(std::move(cond)), body(std::move(b)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class ForStatementNode : public StatementNode {
public:
    enum ForType { C_STYLE, FINEX_RANGE, FOR_IN };
    
    ForType forType;
    
    // C-style for
    std::unique_ptr<ExpressionNode> init;
    std::unique_ptr<ExpressionNode> condition;
    std::unique_ptr<ExpressionNode> update;
    
    // Finex range-based for
    std::unique_ptr<TypeNode> varType;
    std::string varName;
    std::unique_ptr<ExpressionNode> startExpr;
    std::unique_ptr<ExpressionNode> endExpr;
    std::unique_ptr<ExpressionNode> stepExpr;
    
    // For-in
    std::unique_ptr<ExpressionNode> collection;
    
    std::unique_ptr<StatementNode> body;
    
    ForStatementNode(ForType type) : forType(type) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
    
private:
    std::string forTypeToString(ForType t) const;
};

class JumpStatementNode : public StatementNode {
public:
    enum JumpType { BREAK, CONTINUE, RETURN, THROW };
    
    JumpType jumpType;
    std::unique_ptr<ExpressionNode> returnValue;
    
    JumpStatementNode(JumpType type, std::unique_ptr<ExpressionNode> val = nullptr)
        : jumpType(type), returnValue(std::move(val)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
    
private:
    std::string jumpTypeToString(JumpType t) const;
};

class TryCatchStatementNode : public StatementNode {
public:
    std::unique_ptr<CompoundStatementNode> tryBlock;
    std::unique_ptr<TypeNode> exceptionType;
    std::string exceptionVar;
    std::unique_ptr<CompoundStatementNode> catchBlock;
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class CheckStatementNode : public StatementNode {
public:
    std::unique_ptr<ExpressionNode> condition;
    
    CheckStatementNode(std::unique_ptr<ExpressionNode> cond)
        : condition(std::move(cond)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class DeclaratorNode : public ASTNode {
public:
    enum DeclaratorType { SIMPLE, ARRAY, FUNCTION };
    
    DeclaratorType type;
    std::string name;
    
    std::vector<std::unique_ptr<ExpressionNode>> arrayDimensions;
    std::vector<std::unique_ptr<class ParameterNode>> parameters;
    
    DeclaratorNode(const std::string& n, DeclaratorType t = SIMPLE)
        : type(t), name(n) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class ParameterNode : public ASTNode {
public:
    std::unique_ptr<TypeNode> type;
    std::unique_ptr<DeclaratorNode> declarator;
    bool isModifiable;
    std::unique_ptr<ExpressionNode> defaultValue;
    
    ParameterNode() : isModifiable(false) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class DeclarationNode : public ASTNode {
public:
    enum StorageClass { NONE, EXTERN, STATIC };
    enum TypeQualifier { NO_QUAL, CONST, NONNEG };
    
    StorageClass storageClass;
    TypeQualifier typeQualifier;
    std::unique_ptr<TypeNode> type;
    
    struct Declarator {
        std::unique_ptr<DeclaratorNode> declarator;
        std::unique_ptr<ExpressionNode> initializer;
    };
    std::vector<Declarator> declarators;
    
    DeclarationNode() : storageClass(NONE), typeQualifier(NO_QUAL) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
    
private:
    std::string storageClassToString(StorageClass sc) const;
    std::string qualifierToString(TypeQualifier tq) const;
};

class FunctionDefinitionNode : public ASTNode {
public:
    std::unique_ptr<TypeNode> returnType;
    std::unique_ptr<DeclaratorNode> declarator;
    std::unique_ptr<CompoundStatementNode> body;
    
    DeclarationNode::StorageClass storageClass;
    DeclarationNode::TypeQualifier typeQualifier;
    
    FunctionDefinitionNode() 
        : storageClass(DeclarationNode::NONE), 
          typeQualifier(DeclarationNode::NO_QUAL) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class RecordDefinitionNode : public ASTNode {
public:
    std::string name;
    std::vector<std::unique_ptr<ASTNode>> members;
    
    RecordDefinitionNode(const std::string& n) : name(n) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class LabelDefinitionNode : public ASTNode {
public:
    std::string name;
    std::vector<std::string> values;
    
    LabelDefinitionNode(const std::string& n) : name(n) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class ImportStatementNode : public ASTNode {
public:
    std::string libraryName;
    
    ImportStatementNode(const std::string& lib) : libraryName(lib) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class MacroDefinitionNode : public ASTNode {
public:
    std::string name;
    std::unique_ptr<ExpressionNode> value;
    
    MacroDefinitionNode(const std::string& n, std::unique_ptr<ExpressionNode> v)
        : name(n), value(std::move(v)) {}
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class TypeAliasNode : public ASTNode {
public:
    std::string alias;
    std::unique_ptr<TypeNode> originalType;

    TypeAliasNode(const std::string& a, std::unique_ptr<TypeNode> t)
        : alias(a), originalType(std::move(t)) {}

    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class ProgramNode : public ASTNode {
public:
    std::vector<std::unique_ptr<ASTNode>> declarations;
    
    void print(int indent = 0) const override;
    void accept(ASTVisitor* visitor) override;
};

class ASTVisitor {
public:
    virtual ~ASTVisitor() = default;
    
    virtual void visit(TypeNode* node) = 0;
    virtual void visit(BinaryOpNode* node) = 0;
    virtual void visit(UnaryOpNode* node) = 0;
    virtual void visit(AssignmentNode* node) = 0;
    virtual void visit(CastNode* node) = 0;
    virtual void visit(IdentifierNode* node) = 0;
    virtual void visit(LiteralNode* node) = 0;
    virtual void visit(FunctionCallNode* node) = 0;
    virtual void visit(MemberAccessNode* node) = 0;
    virtual void visit(SubscriptNode* node) = 0;
    virtual void visit(InitializerListNode* node) = 0;
    virtual void visit(CompoundStatementNode* node) = 0;
    virtual void visit(ExpressionStatementNode* node) = 0;
    virtual void visit(IfStatementNode* node) = 0;
    virtual void visit(WhileStatementNode* node) = 0;
    virtual void visit(ForStatementNode* node) = 0;
    virtual void visit(JumpStatementNode* node) = 0;
    virtual void visit(TryCatchStatementNode* node) = 0;
    virtual void visit(CheckStatementNode* node) = 0;
    virtual void visit(DeclaratorNode* node) = 0;
    virtual void visit(ParameterNode* node) = 0;
    virtual void visit(DeclarationNode* node) = 0;
    virtual void visit(FunctionDefinitionNode* node) = 0;
    virtual void visit(RecordDefinitionNode* node) = 0;
    virtual void visit(LabelDefinitionNode* node) = 0;
    virtual void visit(ImportStatementNode* node) = 0;
    virtual void visit(MacroDefinitionNode* node) = 0;
    virtual void visit(TypeAliasNode* node) = 0;
    virtual void visit(ProgramNode* node) = 0;
};

#endif // AST_HPP