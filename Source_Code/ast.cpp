#include "../Header_Files/ast.hpp"

void TypeNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Type: ";
    if (kind == USER_DEFINED) {
        std::cout << typeName;
    } else if (kind == GENERIC) {
        std::cout << typeName << "<";
        for (size_t i = 0; i < genericArgs.size(); i++) {
            if (i > 0) std::cout << ", ";
            genericArgs[i]->print(0);
        }
        std::cout << ">";
    } else {
        std::cout << typeKindToString(kind);
    }
    std::cout << std::endl;
}

std::string TypeNode::typeKindToString(TypeKind k) const {
    switch(k) {
        case INT: return "int";
        case REAL: return "real";
        case CHAR: return "char";
        case STRING: return "string";
        case BOOL: return "bool";
        case DATETIME: return "datetime";
        case AMOUNT: return "amount";
        case VOID: return "void";
        default: return "unknown";
    }
}

void TypeNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void BinaryOpNode::print(int indent) const {
    printIndent(indent);
    std::cout << "BinaryOp: " << opToString(op) << std::endl;
    left->print(indent + 1);
    right->print(indent + 1);
}

std::string BinaryOpNode::opToString(OpType o) const {
    switch(o) {
        case ADD: return "+";
        case SUB: return "-";
        case MUL: return "*";
        case DIV: return "/";
        case INT_DIV: return "//";
        case MOD: return "%";
        case POW: return "^";
        case EQ: return "==";
        case NEQ: return "!=";
        case TEQ: return "===";
        case GT: return ">";
        case LT: return "<";
        case GEQ: return ">=";
        case LEQ: return "<=";
        case AND: return "and";
        case OR: return "or";
        case IN: return "in";
        case COMMA: return ",";
        default: return "unknown";
    }
}

void BinaryOpNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void UnaryOpNode::print(int indent) const {
    printIndent(indent);
    std::cout << "UnaryOp: " << opToString(op) << std::endl;
    operand->print(indent + 1);
}

std::string UnaryOpNode::opToString(OpType o) const {
    switch(o) {
        case PLUS: return "+";
        case MINUS: return "-";
        case NOT: return "not";
        default: return "unknown";
    }
}

void UnaryOpNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void AssignmentNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Assignment: " << opToString(op) << std::endl;
    lhs->print(indent + 1);
    rhs->print(indent + 1);
}

std::string AssignmentNode::opToString(OpType o) const {
    switch(o) {
        case ASSIGN: return "=";
        case PLUS_ASSIGN: return "+=";
        case MINUS_ASSIGN: return "-=";
        case MULT_ASSIGN: return "*=";
        case DIV_ASSIGN: return "/=";
        case INT_DIV_ASSIGN: return "//=";
        case MOD_ASSIGN: return "%=";
        case POWER_ASSIGN: return "^=";
        default: return "unknown";
    }
}

void AssignmentNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void CastNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Cast:" << std::endl;
    targetType->print(indent + 1);
    expression->print(indent + 1);
}

void CastNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void IdentifierNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Identifier: " << name << std::endl;
}

void IdentifierNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void LiteralNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Literal[" << typeToString(type) << "]: " << value << std::endl;
}

std::string LiteralNode::typeToString(LiteralType t) const {
    switch(t) {
        case INT: return "int";
        case REAL: return "real";
        case STRING: return "string";
        case CHAR: return "char";
        case BOOL: return "bool";
        case AMOUNT: return "amount";
        case DATETIME: return "datetime";
        default: return "unknown";
    }
}

void LiteralNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void FunctionCallNode::print(int indent) const {
    printIndent(indent);
    std::cout << "FunctionCall:" << std::endl;
    function->print(indent + 1);
    for (const auto& arg : arguments) {
        arg->print(indent + 1);
    }
}

void FunctionCallNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void MemberAccessNode::print(int indent) const {
    printIndent(indent);
    std::cout << "MemberAccess[" << (accessType == ARROW ? "->" : "::") 
              << "]: " << member << std::endl;
    object->print(indent + 1);
}

void MemberAccessNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void SubscriptNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Subscript:" << std::endl;
    array->print(indent + 1);
    index->print(indent + 1);
}

void SubscriptNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void InitializerListNode::print(int indent) const {
    printIndent(indent);
    std::cout << "InitializerList:" << std::endl;
    for (const auto& elem : elements) {
        elem->print(indent + 1);
    }
}

void InitializerListNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void CompoundStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "CompoundStatement:" << std::endl;
    for (const auto& stmt : statements) {
        stmt->print(indent + 1);
    }
}

void CompoundStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void ExpressionStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "ExpressionStatement:" << std::endl;
    if (expression) {
        expression->print(indent + 1);
    }
}

void ExpressionStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void IfStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "IfStatement:" << std::endl;
    printIndent(indent + 1);
    std::cout << "Condition:" << std::endl;
    condition->print(indent + 2);
    printIndent(indent + 1);
    std::cout << "Then:" << std::endl;
    thenBranch->print(indent + 2);
    if (elseBranch) {
        printIndent(indent + 1);
        std::cout << "Else:" << std::endl;
        elseBranch->print(indent + 2);
    }
}

void IfStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void WhileStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "WhileStatement:" << std::endl;
    condition->print(indent + 1);
    body->print(indent + 1);
}

void WhileStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void ForStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "ForStatement[" << forTypeToString(forType) << "]:" << std::endl;
    
    if (forType == C_STYLE) {
        if (init) init->print(indent + 1);
        if (condition) condition->print(indent + 1);
        if (update) update->print(indent + 1);
    } else if (forType == FINEX_RANGE) {
        printIndent(indent + 1);
        std::cout << "Variable: " << varName << std::endl;
        if (varType) varType->print(indent + 1);
        if (startExpr) startExpr->print(indent + 1);
        if (endExpr) endExpr->print(indent + 1);
        if (stepExpr) stepExpr->print(indent + 1);
    } else if (forType == FOR_IN) {
        printIndent(indent + 1);
        std::cout << "Variable: " << varName << std::endl;
        if (collection) collection->print(indent + 1);
    }
    
    if (body) body->print(indent + 1);
}

std::string ForStatementNode::forTypeToString(ForType t) const {
    switch(t) {
        case C_STYLE: return "C-style";
        case FINEX_RANGE: return "Range";
        case FOR_IN: return "For-in";
        default: return "unknown";
    }
}

void ForStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void JumpStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "JumpStatement: " << jumpTypeToString(jumpType) << std::endl;
    if (returnValue) {
        returnValue->print(indent + 1);
    }
}

std::string JumpStatementNode::jumpTypeToString(JumpType t) const {
    switch(t) {
        case BREAK: return "break";
        case CONTINUE: return "continue";
        case RETURN: return "return";
        case THROW: return "throw";
        default: return "unknown";
    }
}

void JumpStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void TryCatchStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "TryCatchStatement:" << std::endl;
    printIndent(indent + 1);
    std::cout << "Try:" << std::endl;
    tryBlock->print(indent + 2);
    printIndent(indent + 1);
    std::cout << "Catch(" << exceptionVar << "):" << std::endl;
    if (exceptionType) exceptionType->print(indent + 2);
    catchBlock->print(indent + 2);
}

void TryCatchStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void CheckStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "CheckStatement:" << std::endl;
    condition->print(indent + 1);
}

void CheckStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void DeclaratorNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Declarator: " << name;
    if (type == ARRAY) std::cout << " [array]";
    if (type == FUNCTION) std::cout << " [function]";
    std::cout << std::endl;
}

void DeclaratorNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void ParameterNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Parameter:" << std::endl;
    if (type) type->print(indent + 1);
    if (declarator) declarator->print(indent + 1);
    if (isModifiable) {
        printIndent(indent + 1);
        std::cout << "modifiable" << std::endl;
    }
    if (defaultValue) {
        printIndent(indent + 1);
        std::cout << "Default:" << std::endl;
        defaultValue->print(indent + 2);
    }
}

void ParameterNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void DeclarationNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Declaration:" << std::endl;
    if (storageClass != NONE) {
        printIndent(indent + 1);
        std::cout << "Storage: " << storageClassToString(storageClass) << std::endl;
    }
    if (typeQualifier != NO_QUAL) {
        printIndent(indent + 1);
        std::cout << "Qualifier: " << qualifierToString(typeQualifier) << std::endl;
    }
    if (type) type->print(indent + 1);
    for (const auto& decl : declarators) {
        decl.declarator->print(indent + 1);
        if (decl.initializer) {
            printIndent(indent + 2);
            std::cout << "Initializer:" << std::endl;
            decl.initializer->print(indent + 3);
        }
    }
}

std::string DeclarationNode::storageClassToString(StorageClass sc) const {
    switch(sc) {
        case EXTERN: return "extern";
        case STATIC: return "static";
        default: return "none";
    }
}

std::string DeclarationNode::qualifierToString(TypeQualifier tq) const {
    switch(tq) {
        case CONST: return "const";
        case NONNEG: return "nonneg";
        default: return "none";
    }
}

void DeclarationNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void FunctionDefinitionNode::print(int indent) const {
    printIndent(indent);
    std::cout << "FunctionDefinition:" << std::endl;
    if (returnType) returnType->print(indent + 1);
    if (declarator) declarator->print(indent + 1);
    if (body) body->print(indent + 1);
}

void FunctionDefinitionNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void RecordDefinitionNode::print(int indent) const {
    printIndent(indent);
    std::cout << "RecordDefinition: " << name << std::endl;
    for (const auto& member : members) {
        member->print(indent + 1);
    }
}

void RecordDefinitionNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void LabelDefinitionNode::print(int indent) const {
    printIndent(indent);
    std::cout << "LabelDefinition: " << name << " { ";
    for (size_t i = 0; i < values.size(); i++) {
        if (i > 0) std::cout << ", ";
        std::cout << values[i];
    }
    std::cout << " }" << std::endl;
}

void LabelDefinitionNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void ImportStatementNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Import: " << libraryName << std::endl;
}

void ImportStatementNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void MacroDefinitionNode::print(int indent) const {
    printIndent(indent);
    std::cout << "MacroDefinition: " << name << std::endl;
    value->print(indent + 1);
}

void MacroDefinitionNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void TypeAliasNode::print(int indent) const {
    printIndent(indent);
    std::cout << "TypeAlias: " << alias << " = ";
    std::cout << "(Type)" << std::endl; 
    originalType->print(indent + 1);
}

void TypeAliasNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}

void ProgramNode::print(int indent) const {
    printIndent(indent);
    std::cout << "Program:" << std::endl;
    for (const auto& decl : declarations) {
        decl->print(indent + 1);
    }
}

void ProgramNode::accept(ASTVisitor* visitor) {
    visitor->visit(this);
}