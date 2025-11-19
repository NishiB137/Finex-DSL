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
    #include <fstream>
    #include "ast.hpp"
    #include "symbol_table.hpp"
    #include "semantic_analyzer.hpp"
    
    void yyerror(const char *s);
    int yylex();

    extern FILE* yyin;
    extern int yylineno;
    extern int columnno;
    extern char* yytext; 
    
    // Store filename globally for error reporting
    std::string current_filename = "stdin";
    
    // Root of the AST
    ProgramNode* root = nullptr;
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

    template<typename T>
    T* setLoc(T* node) {
        if (node) {
            node->line = yylineno;
            node->column = columnno;
        }
        return node;
    }
%}

// ENABLE VERBOSE ERROR MESSAGES
%define parse.error verbose

%union{
    char* str;
    int type;
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
    std::vector<std::unique_ptr<ASTNode>>* nodeList;
    std::vector<std::unique_ptr<ExpressionNode>>* exprList;
    std::vector<std::unique_ptr<TypeNode>>* typeList;
    std::vector<std::unique_ptr<ParameterNode>>* paramList;
    std::vector<DeclarationNode::Declarator>* declList;
    std::vector<std::string>* strList;
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
%type <node> external_declaration block_item struct_declaration using_declaration
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
        
        // Check for nullptr in case error recovery kicked in
        if ($1) $$->declarations.push_back(std::unique_ptr<ASTNode>($1));
        root = $$;
    }
    | program external_declaration {
        for(auto& d : extra_defs) {
             $1->declarations.push_back(std::move(d));
        }
        extra_defs.clear();
        
        // Check for nullptr
        if ($2) $1->declarations.push_back(std::unique_ptr<ASTNode>($2));
        $$ = $1;
        root = $$;
    }
    ;

external_declaration
    : import_statement { $$ = $1; }
    | macro_definition { $$ = $1; }
    | using_declaration { $$ = $1; }
    | declaration { $$ = $1; }
    | function_definition { $$ = $1; }
    /* GLOBAL RECOVERY: Valid here */
    | error ';' { 
        yyerrok; 
        $$ = nullptr; 
    }
    ;

import_statement
    : IMPORT_LIB ';' {
        $$ = setLoc(new ImportStatementNode($1));
        free($1);
    }
    ;

macro_definition
    : DEFINE IDENTIFIER AS expression ';' {
        $$ = setLoc(new MacroDefinitionNode($2, std::unique_ptr<ExpressionNode>($4)));
        free($2);
    }
    ;

using_declaration
    : USING type_specifier AS IDENTIFIER ';' {
        $$ = setLoc(new TypeAliasNode($4, std::unique_ptr<TypeNode>($2)));
        add_type_name($4);
        free($4);
    }
    ;

declaration
    : declaration_specifiers ';' {
        $$ = setLoc(new DeclarationNode());
        if ($1.storageClass & (1 << 16)) $$->storageClass = DeclarationNode::EXTERN;
        else if ($1.storageClass & (1 << 17)) $$->storageClass = DeclarationNode::STATIC;
        if ($1.typeQualifier & (1 << 18)) $$->typeQualifier = DeclarationNode::CONST;
        else if ($1.typeQualifier & (1 << 19)) $$->typeQualifier = DeclarationNode::NONNEG;
        $$->type = std::unique_ptr<TypeNode>($1.type);
    }
    | declaration_specifiers init_declarator_list ';' {
        $$ = setLoc(new DeclarationNode());
        if ($1.storageClass & (1 << 16)) $$->storageClass = DeclarationNode::EXTERN;
        else if ($1.storageClass & (1 << 17)) $$->storageClass = DeclarationNode::STATIC;
        if ($1.typeQualifier & (1 << 18)) $$->typeQualifier = DeclarationNode::CONST;
        else if ($1.typeQualifier & (1 << 19)) $$->typeQualifier = DeclarationNode::NONNEG;
        $$->type = std::unique_ptr<TypeNode>($1.type);
        $$->declarators = std::move(*$2);
        delete $2;
    }
    /* NO ERROR RECOVERY HERE (Handled by block_item or external_declaration) */
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
    : INT_T { $$ = setLoc(new TypeNode(TypeNode::INT)); }
    | REAL_T { $$ = setLoc(new TypeNode(TypeNode::REAL)); }
    | CHAR_T { $$ = setLoc(new TypeNode(TypeNode::CHAR)); }
    | STRING_T { $$ = setLoc(new TypeNode(TypeNode::STRING)); }
    | BOOL_T { $$ = setLoc(new TypeNode(TypeNode::BOOL)); }
    | DATETIME_T { $$ = setLoc(new TypeNode(TypeNode::DATETIME)); }
    | AMOUNT_T { $$ = setLoc(new TypeNode(TypeNode::AMOUNT)); }
    | VOID { $$ = setLoc(new TypeNode(TypeNode::VOID)); }
    | user_type_specifier { $$ = $1; }
    | TYPE_NAME LT type_argument_list GT %prec ANGULAR_BRACKS {
        $$ = setLoc(new TypeNode($1));
        $$->kind = TypeNode::GENERIC;
        $$->genericArgs = std::move(*$3);
        delete $3;
        free($1);
    }
    ;

user_type_specifier 
    : record_specifier { $$ = $1; }
    | label_specifier { $$ = $1; }
    | TYPE_NAME { $$ = setLoc(new TypeNode($1)); free($1); }   
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
        setLoc(def);
        def->members = std::move(*$3);
        delete $3;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = setLoc(new TypeNode($2));
        free($2);
    }
    | RECORD IDENTIFIER {
        add_type_name($2);
        $$ = setLoc(new TypeNode($2));
        free($2);
    }
    | RECORD record_body {
        RecordDefinitionNode* def = new RecordDefinitionNode("anonymous");
        setLoc(def);
        def->members = std::move(*$2);
        delete $2;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = setLoc(new TypeNode("anonymous"));
    }
    ;

record_body
    : '{' struct_declaration_list '}' { $$ = $2; }
    ;

struct_declaration_list
    : struct_declaration {
        $$ = new std::vector<std::unique_ptr<ASTNode>>();
        // Check nullptr for recovery
        if ($1) $$->push_back(std::unique_ptr<ASTNode>($1));
    }
    | struct_declaration_list struct_declaration {
        if ($2) $1->push_back(std::unique_ptr<ASTNode>($2));
        $$ = $1;
    }
    ;

struct_declaration 
    : declaration { $$ = $1; }
    | function_definition { $$ = $1; }
    /* NO ERROR RECOVERY HERE */
    ;

label_specifier
    : LABEL IDENTIFIER {
        add_type_name($2);
        $$ = setLoc(new TypeNode($2));
        free($2);
    }
    | LABEL IDENTIFIER label_body {
        add_type_name($2);
        LabelDefinitionNode* def = new LabelDefinitionNode($2);
        setLoc(def);
        def->values = std::move(*$3);
        delete $3;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = setLoc(new TypeNode($2));
        free($2);
    }
    | LABEL label_body {
        LabelDefinitionNode* def = new LabelDefinitionNode("anonymous");
        setLoc(def);
        def->values = std::move(*$2);
        delete $2;
        extra_defs.push_back(std::unique_ptr<ASTNode>(def));
        $$ = setLoc(new TypeNode("anonymous"));
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
        setLoc(init);
        init->elements = std::move(*$2);
        delete $2;
        $$ = init;
    }
    | '{' initializer_list ',' '}' {
        InitializerListNode* init = new InitializerListNode();
        setLoc(init);
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
        $$ = setLoc(new DeclaratorNode($1, DeclaratorNode::SIMPLE));
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
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::COMMA, 
                              std::unique_ptr<ExpressionNode>($1),
                              std::unique_ptr<ExpressionNode>($3)));
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
        $$ = setLoc(new AssignmentNode(op, 
                               std::unique_ptr<ExpressionNode>($1),
                               std::unique_ptr<ExpressionNode>($3)));
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
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::OR,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

logical_and_expression
    : membership_expression { $$ = $1; }
    | logical_and_expression AND membership_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::AND,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

membership_expression
    : equality_expression { $$ = $1; }
    | equality_expression IN equality_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::IN,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

equality_expression
    : relational_expression { $$ = $1; }
    | equality_expression EQ relational_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::EQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | equality_expression NEQ relational_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::NEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | equality_expression TEQ relational_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::TEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

relational_expression
    : additive_expression { $$ = $1; }
    | relational_expression GT additive_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::GT,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | relational_expression LT additive_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::LT,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | relational_expression GEQ additive_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::GEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | relational_expression LEQ additive_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::LEQ,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

additive_expression
    : multiplicative_expression { $$ = $1; }
    | additive_expression '+' multiplicative_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::ADD,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | additive_expression '-' multiplicative_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::SUB,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

multiplicative_expression
    : exponential_expression { $$ = $1; }
    | multiplicative_expression '*' exponential_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::MUL,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | multiplicative_expression '/' exponential_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::DIV,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | multiplicative_expression INT_DIV exponential_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::INT_DIV,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    | multiplicative_expression '%' exponential_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::MOD,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

exponential_expression
    : cast_expression { $$ = $1; }
    | cast_expression '^' exponential_expression {
        $$ = setLoc(new BinaryOpNode(BinaryOpNode::POW,
                             std::unique_ptr<ExpressionNode>($1),
                             std::unique_ptr<ExpressionNode>($3)));
    }
    ;

cast_expression
    : unary_expression { $$ = $1; }
    | '(' specifier_qualifier_list ')' cast_expression %prec CAST {
        if ($2.type == nullptr) {
             $2.type = new TypeNode(TypeNode::INT); 
        }
        $$ = setLoc(new CastNode(std::unique_ptr<TypeNode>($2.type),
                         std::unique_ptr<ExpressionNode>($4)));
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
           // Multiple type specifiers
        }
        $$.type = $1;
        $$.storageClass = 0;
        $$.typeQualifier = $2.typeQualifier;
    }
    ;

unary_expression
    : postfix_expression { $$ = $1; }
    | '+' cast_expression %prec UPLUS {
        $$ = setLoc(new UnaryOpNode(UnaryOpNode::PLUS, std::unique_ptr<ExpressionNode>($2)));
    }
    | '-' cast_expression %prec UMINUS {
        $$ = setLoc(new UnaryOpNode(UnaryOpNode::MINUS, std::unique_ptr<ExpressionNode>($2)));
    }
    | NOT cast_expression %prec NOT {
        $$ = setLoc(new UnaryOpNode(UnaryOpNode::NOT, std::unique_ptr<ExpressionNode>($2)));
    }
    ;

postfix_expression
    : primary_expression { $$ = $1; }
    | postfix_expression DCOLON IDENTIFIER {
        $$ = setLoc(new MemberAccessNode(MemberAccessNode::DOUBLE_COLON,
                                 std::unique_ptr<ExpressionNode>($1), $3));
        free($3);
    }
    | postfix_expression '(' ')' {
        $$ = setLoc(new FunctionCallNode(std::unique_ptr<ExpressionNode>($1)));
    }
    | postfix_expression '(' argument_expression_list ')' {
        FunctionCallNode* func = new FunctionCallNode(std::unique_ptr<ExpressionNode>($1));
        setLoc(func);
        func->arguments = std::move(*$3);
        delete $3;
        $$ = func;
    }
    | postfix_expression '[' expression ']' {
        $$ = setLoc(new SubscriptNode(std::unique_ptr<ExpressionNode>($1),
                              std::unique_ptr<ExpressionNode>($3)));
    }
    | postfix_expression ARROW IDENTIFIER {
        $$ = setLoc(new MemberAccessNode(MemberAccessNode::ARROW,
                                 std::unique_ptr<ExpressionNode>($1), $3));
        free($3);
    }
    ;

primary_expression
    : IDENTIFIER {
        $$ = setLoc(new IdentifierNode($1));
        free($1);
    }
    | INT_LITERAL {
        $$ = setLoc(new LiteralNode(LiteralNode::INT, $1));
        free($1);
    }
    | REAL_LITERAL {
        $$ = setLoc(new LiteralNode(LiteralNode::REAL, $1));
        free($1);
    }
    | STRING_LITERAL {
        $$ = setLoc(new LiteralNode(LiteralNode::STRING, $1));
        free($1);
    }
    | CHAR_LITERAL {
        $$ = setLoc(new LiteralNode(LiteralNode::CHAR, $1));
        free($1);
    }
    | BOOL_LITERAL {
        $$ = setLoc(new LiteralNode(LiteralNode::BOOL, $1));
        free($1);
    }
    | AMOUNT_LITERAL {
        $$ = setLoc(new LiteralNode(LiteralNode::AMOUNT, $1));
        free($1);
    }
    | DATETIME_LITERAL {
        $$ = setLoc(new LiteralNode(LiteralNode::DATETIME, $1));
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
        $$ = setLoc(new ParameterNode());
        if ($1.type == nullptr) {
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::INT)); 
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
        $$->declarator = std::unique_ptr<DeclaratorNode>($2);
        $$->isModifiable = false;
    }
    | declaration_specifiers declarator MODIFIABLE {
        $$ = setLoc(new ParameterNode());
        if ($1.type == nullptr) {
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::INT));
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
        $$->declarator = std::unique_ptr<DeclaratorNode>($2);
        $$->isModifiable = true;
    }
    | declaration_specifiers declarator DEFAULT logical_or_expression {
        $$ = setLoc(new ParameterNode());
        if ($1.type == nullptr) {
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::INT));
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
        $$->declarator = std::unique_ptr<DeclaratorNode>($2);
        $$->defaultValue = std::unique_ptr<ExpressionNode>($4);
        $$->isModifiable = false;
    }
    | declaration_specifiers {
        $$ = setLoc(new ParameterNode());
        if ($1.type == nullptr) {
            $$->type = std::unique_ptr<TypeNode>(new TypeNode(TypeNode::VOID)); 
        } else {
            $$->type = std::unique_ptr<TypeNode>($1.type);
        }
    }
    ;

function_definition
    : declaration_specifiers declarator compound_statement {
        $$ = setLoc(new FunctionDefinitionNode());
        if ($1.storageClass & (1 << 16)) $$->storageClass = DeclarationNode::EXTERN;
        else if ($1.storageClass & (1 << 17)) $$->storageClass = DeclarationNode::STATIC;
        else $$->storageClass = DeclarationNode::NONE;
        
        if ($1.typeQualifier & (1 << 18)) $$->typeQualifier = DeclarationNode::CONST;
        else if ($1.typeQualifier & (1 << 19)) $$->typeQualifier = DeclarationNode::NONNEG;
        else $$->typeQualifier = DeclarationNode::NO_QUAL;

        if ($1.type == nullptr) {
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
        $$ = setLoc(new CompoundStatementNode());
    }
    | '{' block_item_list '}' {
        CompoundStatementNode* comp = new CompoundStatementNode();
        setLoc(comp);
        comp->statements = std::move(*$2);
        delete $2;
        $$ = comp;
    }
    ;

block_item_list
    : block_item {
        $$ = new std::vector<std::unique_ptr<ASTNode>>();
        // Check if block_item returned NULL (due to error)
        if ($1) $$->push_back(std::unique_ptr<ASTNode>($1));
    }
    | block_item_list block_item {
        if ($2) $1->push_back(std::unique_ptr<ASTNode>($2));
        $$ = $1;
    }
    ;

block_item
    : declaration { $$ = $1; }
    | statement { $$ = $1; }
    /* LOCAL RECOVERY: Valid here */
    | error ';' { 
        yyerrok; 
        $$ = nullptr; 
    }
    ;

statement
    : compound_statement { $$ = $1; }
    | expression_statement { $$ = $1; }
    | selection_statement { $$ = $1; }
    | iteration_statement { $$ = $1; }
    | jump_statement { $$ = $1; }
    | exception_statement { $$ = $1; }
    /* NO ERROR RECOVERY HERE (Handled by block_item) */
    ;

expression_statement
    : ';' {
        $$ = setLoc(new ExpressionStatementNode());
    }
    | expression ';' {
        $$ = setLoc(new ExpressionStatementNode(std::unique_ptr<ExpressionNode>($1)));
    }
    ;

selection_statement
    : IF '(' expression ')' statement %prec NO_ELSE {
        $$ = setLoc(new IfStatementNode(std::unique_ptr<ExpressionNode>($3),
                                std::unique_ptr<StatementNode>($5)));
    }
    | IF '(' expression ')' statement ELSE statement {
        $$ = setLoc(new IfStatementNode(std::unique_ptr<ExpressionNode>($3),
                                std::unique_ptr<StatementNode>($5),
                                std::unique_ptr<StatementNode>($7)));
    }
    ;

iteration_statement
    : WHILE '(' expression ')' statement {
        $$ = setLoc(new WhileStatementNode(std::unique_ptr<ExpressionNode>($3),
                                   std::unique_ptr<StatementNode>($5)));
    }
    | FOR '(' expression_statement expression_statement ')' statement {
        ForStatementNode* forNode = new ForStatementNode(ForStatementNode::C_STYLE);
        setLoc(forNode);
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
        setLoc(forNode);
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
        setLoc(forNode);
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
        setLoc(forNode);
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
        setLoc(forNode);
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
        $$ = setLoc(new JumpStatementNode(JumpStatementNode::CONTINUE));
    }
    | BREAK ';' {
        $$ = setLoc(new JumpStatementNode(JumpStatementNode::BREAK));
    }
    | RETURN expression ';' {
        $$ = setLoc(new JumpStatementNode(JumpStatementNode::RETURN,
                                  std::unique_ptr<ExpressionNode>($2)));
    }
    | RETURN ';' {
        $$ = setLoc(new JumpStatementNode(JumpStatementNode::RETURN));
    }
    | THROW expression ';' {
        $$=setLoc(new JumpStatementNode(JumpStatementNode::THROW, std::unique_ptr<ExpressionNode>($2)));
    }
    ;

exception_statement
    : TRY compound_statement CATCH '(' type_specifier declarator ')' compound_statement {
        TryCatchStatementNode* tryNode = new TryCatchStatementNode();
        setLoc(tryNode);
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
        setLoc(tryNode);
        tryNode->tryBlock = std::unique_ptr<CompoundStatementNode>(
            dynamic_cast<CompoundStatementNode*>($2));
        tryNode->exceptionType = std::unique_ptr<TypeNode>($5);
        tryNode->catchBlock = std::unique_ptr<CompoundStatementNode>(
            dynamic_cast<CompoundStatementNode*>($7));
        $$ = tryNode;
    }
    | CHECK '(' expression ')' ';' {
        $$ = setLoc(new CheckStatementNode(std::unique_ptr<ExpressionNode>($3)));
    }
    ;

%%

// Enhanced error reporting with caret pointing to the specific column
void yyerror(const char *s) {
    std::cerr << "\n\033[1;31mError:\033[0m " << s << "\n";
    std::cerr << "Location: " << current_filename << ":" << yylineno << ":" << columnno << "\n";

    if (!current_filename.empty() && current_filename != "stdin") {
        std::ifstream file(current_filename);
        if (file.is_open()) {
            std::string line;
            int current_line = 1;
            while (std::getline(file, line)) {
                if (current_line == yylineno) {
                    std::cerr << "      |\n";
                    std::cerr << " " << current_line << "    | " << line << "\n";
                    std::cerr << "      | ";
                    
                    // Approximate caret position. 
                    // Note: columnno is usually the END of the token in this simple setup.
                    // We back up by token length if we can, otherwise just point to columnno.
                    int token_len = (yytext) ? strlen(yytext) : 1;
                    int start_pos = (columnno > token_len) ? (columnno - token_len) : 0;
                    
                    // CHANGED INT TO SIZE_T TO FIX WARNING
                    for (size_t i = 0; i < (size_t)start_pos; i++) {
                        if (i < line.length() && line[i] == '\t') std::cerr << "\t";
                        else std::cerr << " ";
                    }
                    std::cerr << "\033[1;33m^\033[0m\n"; // Yellow Caret
                    std::cerr << "      |\n";
                    break;
                }
                current_line++;
            }
            file.close();
        }
    }
    std::cerr << "\n";
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
        current_filename = std::string(argv[1]);
    } else {
        current_filename = "stdin";
    }
    
    if (yyparse() == 0) {
        printf("\n=== Parsing finished successfully ===\n\n");
        if (root) {
            // 1. Print AST
            printf("=== AST Output ===\n");
            root->print();

            // 2. Run Semantic Analysis
            printf("\n=== Semantic Analysis ===\n");
            SymbolTable symTab;

            // Pass 1: Declaration Scan
            printf("Running Pass 1: Declarations...\n");
            DeclarationPass pass1(symTab);
            root->accept(&pass1);

            // Pass 2: Usage Checks
            printf("Running Pass 2: Checks...\n");
            SemanticPass pass2(symTab);
            root->accept(&pass2);
            
            // Print Symbol Table state
            symTab.print_table();
        }
    } else {
    fprintf(stderr, "\n\033[1;31mError:\033[0m compilation terminated due to syntax errors \n");        
    }
    
    if (yyin != stdin) fclose(yyin);
    return 0;
}