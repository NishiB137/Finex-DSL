%code requires {
    #include <string>
    #include <vector>
    #include <memory>
    #include "ast.hpp"
}

%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <stdbool.h>
    #include <iostream>
    #include <vector>    
    #include <memory>    
    #include "ast.hpp"   
    
    void yyerror(const char *s);
    int yylex();

    extern FILE* yyin;
    extern int yylineno;
    
    // Root of the AST
    ProgramNode* root = nullptr;

    // Temporary storage for definitions
    std::vector<std::unique_ptr<ASTNode>> extra_defs;

    #define MAX_TYPES 1024
    static char *type_names[MAX_TYPES];
    static int type_count = 0;
    
    void add_type_name(const char *s) {
        if (type_count < MAX_TYPES) {
            type_names[type_count++] = strdup(s);
        }
    }

    bool is_type_name(const char *s) {
        for(int i = 0; i < type_count; i++) {
            if(strcmp(type_names[i], s) == 0)
                return true;
        }
        return false;
    }

    static const char *builtin_generics[] = {"list", "map", "set", "queue", "stack", "multimap", "multiset", "dequeue", "priority_queue"};
    static int builtin_generic_count = 9;

    bool is_builtin_generic(const char *s) {
        for (int i = 0; i < builtin_generic_count; i++) {
            if (strcmp(s, builtin_generics[i]) == 0)
                return true;
        }
        return false;
    }
%}

%union{
    char* str;
    int type;

    // AST node pointers
    ASTNode* node;
    ProgramNode* program;
    ExpressionNode* expr;
    StatementNode* stmt;
    DeclarationNode* decl;
    DeclaratorNode* declarator;
    TypeNode* typeNode;
    ParameterNode* param;
    FunctionDefinitionNode* funcDef;
    CompoundStatementNode* compoundStmt;
    ImportStatementNode* importStmt;
    MacroDefinitionNode* macroDef;
    
    // Lists
    std::vector<std::unique_ptr<ASTNode>>* nodeList;
    std::vector<std::unique_ptr<ExpressionNode>>* exprList;
    std::vector<std::unique_ptr<TypeNode>>* typeList;
    std::vector<std::unique_ptr<ParameterNode>>* paramList;
    std::vector<DeclarationNode::Declarator>* declList;
    std::vector<std::string>* strList;
    
    // Structure to hold complete declaration specifiers
    struct {
        TypeNode* type;
        int storageClass;
        int typeQualifier;
    } declSpec;
}

/* Terminals */
%token <str> INT_LITERAL REAL_LITERAL AMOUNT_LITERAL DATETIME_LITERAL STRING_LITERAL CHAR_LITERAL BOOL_LITERAL IDENTIFIER IMPORT_LIB TYPE_NAME
%token <type> INT_T REAL_T CHAR_T STRING_T BOOL_T DATETIME_T AMOUNT_T RECORD LABEL

/* Keywords */
%token IF ELSE FOR WHILE FROM TO STEP IN
%token TRY CATCH THROW CHECK
%token MODIFIABLE DEFAULT AS RETURN VOID
%token CONST NONNEG EXTERN STATIC USING
%token BREAK CONTINUE
%token DEFINE

/* Operators */
%token INT_DIV
%token PLUS_ASSIGN MINUS_ASSIGN MULT_ASSIGN DIV_ASSIGN INT_DIV_ASSIGN MOD_ASSIGN POWER_ASSIGN
%token EQ NEQ TEQ GT LT GEQ LEQ
%token AND OR NOT
%token ARROW DCOLON 

/* Non-terminals */
%type <program> program
%type <node> external_declaration block_item struct_declaration
%type <importStmt> import_statement
%type <macroDef> macro_definition
%type <decl> declaration
%type <funcDef> function_definition
%type <typeNode> type_specifier user_type_specifier record_specifier label_specifier
%type <declarator> declarator
%type <param> parameter_declaration
%type <expr> expression assignment_expression logical_or_expression logical_and_expression
%type <expr> membership_expression equality_expression relational_expression additive_expression
%type <expr> multiplicative_expression exponential_expression cast_expression unary_expression
%type <expr> postfix_expression primary_expression initializer
%type <stmt> statement compound_statement expression_statement selection_statement
%type <stmt> iteration_statement jump_statement exception_statement
%type <nodeList> block_item_list struct_declaration_list record_body
%type <exprList> argument_expression_list initializer_list
%type <typeList> type_argument_list
%type <paramList> parameter_list
%type <declList> init_declarator_list
%type <strList> label_list label_body
%type <type> storage_class_specifier type_qualifier assignment_operator
%type <declSpec> declaration_specifiers specifier_qualifier_list

/* Precedence */
%left ','
%right THROW '=' PLUS_ASSIGN MINUS_ASSIGN MULT_ASSIGN DIV_ASSIGN INT_DIV_ASSIGN MOD_ASSIGN POWER_ASSIGN
%left OR
%left AND
%left IN
%left EQ NEQ TEQ
%left GT LT GEQ LEQ
%left '+' '-'
%left '*' '/' INT_DIV '%'
%right '^'
%right UPLUS UMINUS NOT
%right CAST
%nonassoc ANGULAR_BRACKS
%left '(' ')' '[' ']' ARROW
%nonassoc NO_ELSE
%nonassoc ELSE
%left DCOLON

%%

program
    : external_declaration {
        $$ = new ProgramNode();
        for(auto& d : extra_defs) {
             $$->declarations.push_back(std::move(d));
        }
        extra_defs.clear();
        
        $$->declarations.push_back(std::unique_ptr<ASTNode>($1));
        root = $$;
    }
    | program external_declaration {
        for(auto& d : extra_defs) {
             $1->declarations.push_back(std::move(d));
        }
        extra_defs.clear();
        
        $1->declarations.push_back(std::unique_ptr<ASTNode>($2));
        $$ = $1;
        root = $$;
    }
    ;

external_declaration
    : import_statement { $$ = $1; }
    | macro_definition { $$ = $1; }
    | declaration { $$ = $1; }
    | function_definition { $$ = $1; }
    ;

import_statement
    : IMPORT_LIB ';' {
        $$ = new ImportStatementNode($1);
        free($1);
    }
    ;

macro_definition
    : DEFINE IDENTIFIER AS expression ';' {
        $$ = new MacroDefinitionNode($2, std::unique_ptr<ExpressionNode>($4));
        free($2);
    }
    ;

declaration
    : declaration_specifiers ';' {
        $$ = new DeclarationNode();
        if ($1.storageClass & (1 << 16)) $$->storageClass = DeclarationNode::EXTERN;
        else if ($1.storageClass & (1 << 17)) $$->storageClass = DeclarationNode::STATIC;
        
        if ($1.typeQualifier & (1 << 18)) $$->typeQualifier = DeclarationNode::CONST;
        else if ($1.typeQualifier & (1 << 19)) $$->typeQualifier = DeclarationNode::NONNEG;
        
        $$->type = std::unique_ptr<TypeNode>($1.type);
    }
    | declaration_specifiers init_declarator_list ';' {
        $$ = new DeclarationNode();
        if ($1.storageClass & (1 << 16)) $$->storageClass = DeclarationNode::EXTERN;
        else if ($1.storageClass & (1 << 17)) $$->storageClass = DeclarationNode::STATIC;
        
        if ($1.typeQualifier & (1 << 18)) $$->typeQualifier = DeclarationNode::CONST;
        else if ($1.typeQualifier & (1 << 19)) $$->typeQualifier = DeclarationNode::NONNEG;
        
        $$->type = std::unique_ptr<TypeNode>($1.type);
        $$->declarators = std::move(*$2);
        delete $2;
    }
    ;

declaration_specifiers
    : storage_class_specifier { $$.storageClass = $1; $$.typeQualifier = 0; $$.type = nullptr; }
    | storage_class_specifier declaration_specifiers { $$ = $2; $$.storageClass |= $1; }
    | type_qualifier { $$.typeQualifier = $1; $$.storageClass = 0; $$.type = nullptr; }
    | type_qualifier declaration_specifiers { $$ = $2; $$.typeQualifier |= $1; }
    | type_specifier { $$.type = $1; $$.storageClass = 0; $$.typeQualifier = 0; }
    ;

storage_class_specifier
    : EXTERN { $$ = (1 << 16); }
    | STATIC { $$ = (1 << 17); }
    ;

type_qualifier
    : CONST { $$ = (1 << 18); }
    | NONNEG { $$ = (1 << 19); }
    ;

type_specifier
    : INT_T { $$ = new TypeNode(TypeNode::INT); }
    | REAL_T { $$ = new TypeNode(TypeNode::REAL); }
    | CHAR_T { $$ = new TypeNode(TypeNode::CHAR); }
    | STRING_T { $$ = new TypeNode(TypeNode::STRING); }
    | BOOL_T { $$ = new TypeNode(TypeNode::BOOL); }
    | DATETIME_T { $$ = new TypeNode(TypeNode::DATETIME); }
    | AMOUNT_T { $$ = new TypeNode(TypeNode::AMOUNT); }
    | VOID { $$ = new TypeNode(TypeNode::VOID); }
    | user_type_specifier { $$ = $1; }
    | TYPE_NAME LT type_argument_list GT %prec ANGULAR_BRACKS {
        $$ = new TypeNode($1);
        $$->kind = TypeNode::GENERIC;
        $$->genericArgs = std::move(*$3);
        delete $3;
        free($1);
    }
    ;

user_type_specifier 
    : record_specifier { $$ = $1; }
    | label_specifier { $$ = $1; }
    | TYPE_NAME { $$ = new TypeNode($1); free($1); }   
    ;

type_argument_list
    : type_specifier {
        $$ = new std::vector<std::unique_ptr<TypeNode>>();
        $$->push_back(std::unique_ptr<TypeNode>($1));
    }
    | type_argument_list ',' type_specifier {
        $1->push_back(std::unique_ptr<TypeNode>($3));
        $$ = $1;
    }
    ;

record_specifier
    : RECORD IDENTIFIER record_body {
        add_type_name($2);
        RecordDefinitionNode* def = new RecordDefinitionNode($2);
        def->members = std::move(*$3);
        delete $3;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = new TypeNode($2);
        free($2);
    }
    | RECORD IDENTIFIER {
        add_type_name($2);
        $$ = new TypeNode($2);
        free($2);
    }
    | RECORD record_body {
        RecordDefinitionNode* def = new RecordDefinitionNode("anonymous");
        def->members = std::move(*$2);
        delete $2;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = new TypeNode("anonymous");
    }
    ;

record_body
    : '{' struct_declaration_list '}' { $$ = $2; }
    ;

struct_declaration_list
    : struct_declaration {
        $$ = new std::vector<std::unique_ptr<ASTNode>>();
        $$->push_back(std::unique_ptr<ASTNode>($1));
    }
    | struct_declaration_list struct_declaration {
        $1->push_back(std::unique_ptr<ASTNode>($2));
        $$ = $1;
    }
    ;

struct_declaration 
    : declaration { $$ = $1; }
    | function_definition { $$ = $1; }
    ;

label_specifier
    : LABEL IDENTIFIER {
        add_type_name($2);
        $$ = new TypeNode($2);
        free($2);
    }
    | LABEL IDENTIFIER label_body {
        add_type_name($2);
        LabelDefinitionNode* def = new LabelDefinitionNode($2);
        def->values = std::move(*$3);
        delete $3;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = new TypeNode($2);
        free($2);
    }
    | LABEL label_body {
        LabelDefinitionNode* def = new LabelDefinitionNode("anonymous");
        def->values = std::move(*$2);
        delete $2;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = new TypeNode("anonymous");
    }
    ;

label_body
    : '{' label_list '}' { $$ = $2; }
    ;

label_list
    : IDENTIFIER {
        $$ = new std::vector<std::string>();
        $$->push_back($1);
        free($1);
    }
    | label_list ',' IDENTIFIER {
        $1->push_back($3);
        $$ = $1;
        free($3);
    }
    ;

init_declarator_list
    : declarator {
        $$ = new std::vector<DeclarationNode::Declarator>();
        DeclarationNode::Declarator d;
        d.declarator = std::unique_ptr<DeclaratorNode>($1);
        $$->push_back(std::move(d));
    }
    | declarator '=' initializer {
        $$ = new std::vector<DeclarationNode::Declarator>();
        DeclarationNode::Declarator d;
        d.declarator = std::unique_ptr<DeclaratorNode>($1);
        d.initializer = std::unique_ptr<ExpressionNode>($3);
        $$->push_back(std::move(d));
    }
    | init_declarator_list ',' declarator {
        DeclarationNode::Declarator d;
        d.declarator = std::unique_ptr<DeclaratorNode>($3);
        $1->push_back(std::move(d));
        $$ = $1;
    }
    | init_declarator_list ',' declarator '=' initializer {
        DeclarationNode::Declarator d;
        d.declarator = std::unique_ptr<DeclaratorNode>($3);
        d.initializer = std::unique_ptr<ExpressionNode>($5);
        $1->push_back(std::move(d));
        $$ = $1;
    }
    ;

initializer
    : assignment_expression { $$ = $1; }
    | '{' initializer_list '}' {
        InitializerListNode* init = new InitializerListNode();
        init->elements = std::move(*$2);
        delete $2;
        $$ = init;
    }
    | '{' initializer_list ',' '}' {
        InitializerListNode* init = new InitializerListNode();
        init->elements = std::move(*$2);
        delete $2;
        $$ = init;
    }
    ;

initializer_list
    : assignment_expression {
        $$ = new std::vector<std::unique_ptr<ExpressionNode>>();
        $$->push_back(std::unique_ptr<ExpressionNode>($1));
    }
    | initializer_list ',' assignment_expression {
        $1->push_back(std::unique_ptr<ExpressionNode>($3));
        $$ = $1;
    }
    ;

declarator
    : IDENTIFIER {
        $$ = new DeclaratorNode($1, DeclaratorNode::SIMPLE);
        free($1);
    }
    | '(' declarator ')' { $$ = $2; }
    | declarator '[' expression ']' {
        $1->type = DeclaratorNode::ARRAY;
        $1->arrayDimensions.push_back(std::unique_ptr<ExpressionNode>($3));
        $$ = $1;
    }
    | declarator '[' ']' {
        $1->type = DeclaratorNode::ARRAY;
        $$ = $1;
    }
    | declarator '(' parameter_list ')' {
        $1->type = DeclaratorNode::FUNCTION;
        $1->parameters = std::move(*$3);
        delete $3;
        $$ = $1;
    }
    | declarator '(' ')' {
        $1->type = DeclaratorNode::FUNCTION;
        $$ = $1;
    }
    ;

expression
    : assignment_expression { $$ = $1; }
    | expression ',' assignment_expression {
        $$ = new BinaryOpNode(BinaryOpNode::COMMA, 
                              std::unique_ptr<ExpressionNode>($1),
                              std::unique_ptr<ExpressionNode>($3));
    }
    ;

assignment_expression
    : logical_or_expression { $$ = $1; }
    | unary_expression assignment_operator assignment_expression {
        AssignmentNode::OpType op;
        switch($2) {
            case 0: op = AssignmentNode::ASSIGN; break;
            case 1: op = AssignmentNode::MULT_ASSIGN; break;
            case 2: op = AssignmentNode::DIV_ASSIGN; break;
            case 3: op = AssignmentNode::INT_DIV_ASSIGN; break;
            case 4: op = AssignmentNode::MOD_ASSIGN; break;
            case 5: op = AssignmentNode::PLUS_ASSIGN; break;
            case 6: op = AssignmentNode::MINUS_ASSIGN; break;
            case 7: op = AssignmentNode::POWER_ASSIGN; break;
            default: op = AssignmentNode::ASSIGN;
        }
        $$ = new AssignmentNode(op, 
                               std::unique_ptr<ExpressionNode>($1),
                               std::unique_ptr<ExpressionNode>($3));
    }
    ;

assignment_operator
    : '=' { $$ = 0; }
    | MULT_ASSIGN { $$ = 1; }
    | DIV_ASSIGN { $$ = 2; }
    | INT_DIV_ASSIGN { $$ = 3; }
    | MOD_ASSIGN { $$ = 4; }
    | PLUS_ASSIGN { $$ = 5; }
    | MINUS_ASSIGN { $$ = 6; }
    | POWER_ASSIGN { $$ = 7; }
    ;

logical_or_expression
    : logical_and_expression { $$ = $1; }
    | logical_or_expression OR logical_and_expression {
        $$ = new BinaryOpNode(BinaryOpNode::OR,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

logical_and_expression
    : membership_expression { $$ = $1; }
    | logical_and_expression AND membership_expression {
        $$ = new BinaryOpNode(BinaryOpNode::AND,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

membership_expression
    : equality_expression { $$ = $1; }
    | equality_expression IN equality_expression {
        $$ = new BinaryOpNode(BinaryOpNode::IN,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

equality_expression
    : relational_expression { $$ = $1; }
    | equality_expression EQ relational_expression {
        $$ = new BinaryOpNode(BinaryOpNode::EQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | equality_expression NEQ relational_expression {
        $$ = new BinaryOpNode(BinaryOpNode::NEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | equality_expression TEQ relational_expression {
        $$ = new BinaryOpNode(BinaryOpNode::TEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

relational_expression
    : additive_expression { $$ = $1; }
    | relational_expression GT additive_expression {
        $$ = new BinaryOpNode(BinaryOpNode::GT,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | relational_expression LT additive_expression {
        $$ = new BinaryOpNode(BinaryOpNode::LT,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | relational_expression GEQ additive_expression {
        $$ = new BinaryOpNode(BinaryOpNode::GEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | relational_expression LEQ additive_expression {
        $$ = new BinaryOpNode(BinaryOpNode::LEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

additive_expression
    : multiplicative_expression { $$ = $1; }
    | additive_expression '+' multiplicative_expression {
        $$ = new BinaryOpNode(BinaryOpNode::ADD,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | additive_expression '-' multiplicative_expression {
        $$ = new BinaryOpNode(BinaryOpNode::SUB,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

multiplicative_expression
    : exponential_expression { $$ = $1; }
    | multiplicative_expression '*' exponential_expression {
        $$ = new BinaryOpNode(BinaryOpNode::MUL,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | multiplicative_expression '/' exponential_expression {
        $$ = new BinaryOpNode(BinaryOpNode::DIV,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | multiplicative_expression INT_DIV exponential_expression {
        $$ = new BinaryOpNode(BinaryOpNode::INT_DIV,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    | multiplicative_expression '%' exponential_expression {
        $$ = new BinaryOpNode(BinaryOpNode::MOD,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

exponential_expression
    : cast_expression { $$ = $1; }
    | cast_expression '^' exponential_expression {
        $$ = new BinaryOpNode(BinaryOpNode::POW,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3));
    }
    ;

cast_expression
    : unary_expression { $$ = $1; }
    | '(' specifier_qualifier_list ')' cast_expression %prec CAST {
        if ($2.type == nullptr) {
            yyerror("Cast requires a type specifier");
            $2.type = new TypeNode(TypeNode::INT); 
        }
        $$ = new CastNode(std::unique_ptr<TypeNode>($2.type),
                         std::unique_ptr<ExpressionNode>($4));
    }
    ;

specifier_qualifier_list
    : type_qualifier {
        $$.type = nullptr;
        $$.storageClass = 0;
        $$.typeQualifier = $1;
    }
    | type_qualifier specifier_qualifier_list {
        $$.type = $2.type;
        $$.storageClass = 0;
        $$.typeQualifier = $1 | $2.typeQualifier;
    }
    | type_specifier {
        $$.type = $1;
        $$.storageClass = 0;
        $$.typeQualifier = 0;
    }
    | type_specifier specifier_qualifier_list {
        if ($2.type != nullptr) {
            yyerror("Multiple type specifiers in specifier-qualifier list");
        }
        $$.type = $1;
        $$.storageClass = 0;
        $$.typeQualifier = $2.typeQualifier;
    }
    ;

unary_expression
    : postfix_expression { $$ = $1; }
    | '+' cast_expression %prec UPLUS {
        $$ = new UnaryOpNode(UnaryOpNode::PLUS, std::unique_ptr<ExpressionNode>($2));
    }
    | '-' cast_expression %prec UMINUS {
        $$ = new UnaryOpNode(UnaryOpNode::MINUS, std::unique_ptr<ExpressionNode>($2));
    }
    | NOT cast_expression %prec NOT {
        $$ = new UnaryOpNode(UnaryOpNode::NOT, std::unique_ptr<ExpressionNode>($2));
    }
    ;

postfix_expression
    : primary_expression { $$ = $1; }
    | postfix_expression DCOLON IDENTIFIER {
        $$ = new MemberAccessNode(MemberAccessNode::DOUBLE_COLON,
                                 std::unique_ptr<ExpressionNode>($1), $3);
        free($3);
    }
    | postfix_expression '(' ')' {
        $$ = new FunctionCallNode(std::unique_ptr<ExpressionNode>($1));
    }
    | postfix_expression '(' argument_expression_list ')' {
        FunctionCallNode* func = new FunctionCallNode(std::unique_ptr<ExpressionNode>($1));
        func->arguments = std::move(*$3);
        delete $3;
        $$ = func;
    }
    | postfix_expression '[' expression ']' {
        $$ = new SubscriptNode(std::unique_ptr<ExpressionNode>($1),
                              std::unique_ptr<ExpressionNode>($3));
    }
    | postfix_expression ARROW IDENTIFIER {
        $$ = new MemberAccessNode(MemberAccessNode::ARROW,
                                 std::unique_ptr<ExpressionNode>($1), $3);
        free($3);
    }
    ;

primary_expression
    : IDENTIFIER {
        $$ = new IdentifierNode($1);
        free($1);
    }
    | INT_LITERAL {
        $$ = new LiteralNode(LiteralNode::INT, $1);
        free($1);
    }
    | REAL_LITERAL {
        $$ = new LiteralNode(LiteralNode::REAL, $1);
        free($1);
    }
    | STRING_LITERAL {
        $$ = new LiteralNode(LiteralNode::STRING, $1);
        free($1);
    }
    | CHAR_LITERAL {
        $$ = new LiteralNode(LiteralNode::CHAR, $1);
        free($1);
    }
    | BOOL_LITERAL {
        $$ = new LiteralNode(LiteralNode::BOOL, $1);
        free($1);
    }
    | AMOUNT_LITERAL {
        $$ = new LiteralNode(LiteralNode::AMOUNT, $1);
        free($1);
    }
    | DATETIME_LITERAL {
        $$ = new LiteralNode(LiteralNode::DATETIME, $1);
        free($1);
    }
    | '(' expression ')' {
        $$ = $2;
    }
    ;

argument_expression_list
    : assignment_expression {
        $$ = new std::vector<std::unique_ptr<ExpressionNode>>();
        $$->push_back(std::unique_ptr<ExpressionNode>($1));
    }
    | argument_expression_list ',' assignment_expression {
        $1->push_back(std::unique_ptr<ExpressionNode>($3));
        $$ = $1;
    }
    ;

parameter_list
    : parameter_declaration {
        $$ = new std::vector<std::unique_ptr<ParameterNode>>();
        $$->push_back(std::unique_ptr<ParameterNode>($1));
    }
    | parameter_list ',' parameter_declaration {
        $1->push_back(std::unique_ptr<ParameterNode>($3));
        $$ = $1;
    }
    ;

parameter_declaration
    : declaration_specifiers declarator {
        $$ = new ParameterNode();
        if ($1.type == nullptr) {
            yyerror("Parameter declaration requires a type specifier");
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::INT)); 
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
        
        $$->declarator = std::unique_ptr<DeclaratorNode>($2);
        $$->isModifiable = false;
    }
    | declaration_specifiers declarator MODIFIABLE {
        $$ = new ParameterNode();
        if ($1.type == nullptr) {
            yyerror("Parameter declaration requires a type specifier");
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::INT));
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
        
        $$->declarator = std::unique_ptr<DeclaratorNode>($2);
        $$->isModifiable = true;
    }
    | declaration_specifiers declarator DEFAULT logical_or_expression {
        $$ = new ParameterNode();
        if ($1.type == nullptr) {
            yyerror("Parameter declaration requires a type specifier");
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::INT));
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
        
        $$->declarator = std::unique_ptr<DeclaratorNode>($2);
        $$->defaultValue = std::unique_ptr<ExpressionNode>($4);
        $$->isModifiable = false;
    }
    | declaration_specifiers {
        $$ = new ParameterNode();
        if ($1.type == nullptr) {
            yyerror("Parameter declaration requires a type specifier");
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::VOID)); 
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
    }
    ;

function_definition
    : declaration_specifiers declarator compound_statement {
        $$ = new FunctionDefinitionNode();
        if ($1.storageClass & (1 << 16)) $$->storageClass = DeclarationNode::EXTERN;
        else if ($1.storageClass & (1 << 17)) $$->storageClass = DeclarationNode::STATIC;
        else $$->storageClass = DeclarationNode::NONE;
        
        if ($1.typeQualifier & (1 << 18)) $$->typeQualifier = DeclarationNode::CONST;
        else if ($1.typeQualifier & (1 << 19)) $$->typeQualifier = DeclarationNode::NONNEG;
        else $$->typeQualifier = DeclarationNode::NO_QUAL;
        
        if ($1.type == nullptr) {
            yyerror("Function definition requires a return type specifier");
            $$->returnType = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::VOID));
        } else {
            $$->returnType = std::unique_ptr<TypeNode>($1.type);
        }
        
        $$->declarator = std::unique_ptr<DeclaratorNode>($2);
        $$->body = std::unique_ptr<CompoundStatementNode>(dynamic_cast<CompoundStatementNode*>($3));
    }
    ;

compound_statement
    : '{' '}' {
        $$ = new CompoundStatementNode();
    }
    | '{' block_item_list '}' {
        CompoundStatementNode* comp = new CompoundStatementNode();
        comp->statements = std::move(*$2);
        delete $2;
        $$ = comp;
    }
    ;

block_item_list
    : block_item {
        $$ = new std::vector<std::unique_ptr<ASTNode>>();
        $$->push_back(std::unique_ptr<ASTNode>($1));
    }
    | block_item_list block_item {
        $1->push_back(std::unique_ptr<ASTNode>($2));
        $$ = $1;
    }
    ;

block_item
    : declaration { $$ = $1; }
    | statement { $$ = $1; }
    ;

statement
    : compound_statement { $$ = $1; }
    | expression_statement { $$ = $1; }
    | selection_statement { $$ = $1; }
    | iteration_statement { $$ = $1; }
    | jump_statement { $$ = $1; }
    | exception_statement { $$ = $1; }
    ;

expression_statement
    : ';' {
        $$ = new ExpressionStatementNode();
    }
    | expression ';' {
        $$ = new ExpressionStatementNode(std::unique_ptr<ExpressionNode>($1));
    }
    ;

selection_statement
    : IF '(' expression ')' statement %prec NO_ELSE {
        $$ = new IfStatementNode(std::unique_ptr<ExpressionNode>($3),
                                std::unique_ptr<StatementNode>($5));
    }
    | IF '(' expression ')' statement ELSE statement {
        $$ = new IfStatementNode(std::unique_ptr<ExpressionNode>($3),
                                std::unique_ptr<StatementNode>($5),
                                std::unique_ptr<StatementNode>($7));
    }
    ;

iteration_statement
    : WHILE '(' expression ')' statement {
        $$ = new WhileStatementNode(std::unique_ptr<ExpressionNode>($3),
                                   std::unique_ptr<StatementNode>($5));
    }
    | FOR '(' expression_statement expression_statement ')' statement {
        ForStatementNode* forNode = new ForStatementNode(ForStatementNode::C_STYLE);
        
        ExpressionStatementNode* initStmt = dynamic_cast<ExpressionStatementNode*>($3);
        if (initStmt && initStmt->expression) {
            forNode->init = std::move(initStmt->expression);
        }

        ExpressionStatementNode* condStmt = dynamic_cast<ExpressionStatementNode*>($4);
        if (condStmt && condStmt->expression) {
            forNode->condition = std::move(condStmt->expression);
        }

        forNode->body = std::unique_ptr<StatementNode>($6);
        delete $3;
        delete $4;
        $$ = forNode;
    }
    | FOR '(' expression_statement expression_statement expression ')' statement {
        ForStatementNode* forNode = new ForStatementNode(ForStatementNode::C_STYLE);
        
        ExpressionStatementNode* initStmt = dynamic_cast<ExpressionStatementNode*>($3);
        if (initStmt && initStmt->expression) {
            forNode->init = std::move(initStmt->expression);
        }

        ExpressionStatementNode* condStmt = dynamic_cast<ExpressionStatementNode*>($4);
        if (condStmt && condStmt->expression) {
            forNode->condition = std::move(condStmt->expression);
        }

        forNode->update = std::unique_ptr<ExpressionNode>($5);
        forNode->body = std::unique_ptr<StatementNode>($7);
        delete $3;
        delete $4;
        $$ = forNode;
    }
    | FOR '(' type_specifier declarator FROM expression TO expression ')' statement {
        ForStatementNode* forNode = new ForStatementNode(ForStatementNode::FINEX_RANGE);
        forNode->varType = std::unique_ptr<TypeNode>($3);
        forNode->varName = $4->name;
        forNode->startExpr = std::unique_ptr<ExpressionNode>($6);
        forNode->endExpr = std::unique_ptr<ExpressionNode>($8);
        forNode->body = std::unique_ptr<StatementNode>($10);
        delete $4;
        $$ = forNode;
    }
    | FOR '(' type_specifier declarator FROM expression TO expression STEP expression ')' statement {
        ForStatementNode* forNode = new ForStatementNode(ForStatementNode::FINEX_RANGE);
        forNode->varType = std::unique_ptr<TypeNode>($3);
        forNode->varName = $4->name;
        forNode->startExpr = std::unique_ptr<ExpressionNode>($6);
        forNode->endExpr = std::unique_ptr<ExpressionNode>($8);
        forNode->stepExpr = std::unique_ptr<ExpressionNode>($10);
        forNode->body = std::unique_ptr<StatementNode>($12);
        delete $4;
        $$ = forNode;
    }
    | FOR '(' type_specifier declarator IN expression ')' statement {
        ForStatementNode* forNode = new ForStatementNode(ForStatementNode::FOR_IN);
        forNode->varType = std::unique_ptr<TypeNode>($3);
        forNode->varName = $4->name;
        forNode->collection = std::unique_ptr<ExpressionNode>($6);
        forNode->body = std::unique_ptr<StatementNode>($8);
        delete $4;
        $$ = forNode;
    }
    ;

jump_statement
    : CONTINUE ';' {
        $$ = new JumpStatementNode(JumpStatementNode::CONTINUE);
    }
    | BREAK ';' {
        $$ = new JumpStatementNode(JumpStatementNode::BREAK);
    }
    | RETURN expression ';' {
        $$ = new JumpStatementNode(JumpStatementNode::RETURN,
                                  std::unique_ptr<ExpressionNode>($2));
    }
    | RETURN ';' {
        $$ = new JumpStatementNode(JumpStatementNode::RETURN);
    }
    ;

exception_statement
    : TRY compound_statement CATCH '(' type_specifier declarator ')' compound_statement {
        TryCatchStatementNode* tryNode = new TryCatchStatementNode();
        tryNode->tryBlock = std::unique_ptr<CompoundStatementNode>(
            dynamic_cast<CompoundStatementNode*>($2));
        tryNode->exceptionType = std::unique_ptr<TypeNode>($5);
        tryNode->exceptionVar = $6->name;
        tryNode->catchBlock = std::unique_ptr<CompoundStatementNode>(
            dynamic_cast<CompoundStatementNode*>($8));
        delete $6;
        $$ = tryNode;
    }
    | TRY compound_statement CATCH '(' type_specifier ')' compound_statement {
        TryCatchStatementNode* tryNode = new TryCatchStatementNode();
        tryNode->tryBlock = std::unique_ptr<CompoundStatementNode>(
            dynamic_cast<CompoundStatementNode*>($2));
        tryNode->exceptionType = std::unique_ptr<TypeNode>($5);
        tryNode->catchBlock = std::unique_ptr<CompoundStatementNode>(
            dynamic_cast<CompoundStatementNode*>($7));
        $$ = tryNode;
    }
    | CHECK '(' expression ')' ';' {
        $$ = new CheckStatementNode(std::unique_ptr<ExpressionNode>($3));
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

int main(int argc, char* argv[]) {
    printf("Parsing...\n");
    yyin = stdin;
    if(argc == 2){
        yyin = fopen(argv[1], "r");
        if(!yyin){
            fprintf(stderr, "Error opening file: %s\n", argv[1]);
            return 1;
        }
    }
    
    if (yyparse() == 0) {
        printf("\n=== Parsing finished successfully ===\n\n");
        if (root) {
            printf("=== AST Output ===\n");
            root->print();
        }
    } else {
        fprintf(stderr, "Parsing failed.\n");
    }
    
    if (yyin != stdin) fclose(yyin);
    return 0;
}