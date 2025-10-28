%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
	#include <stdbool.h>

    void yyerror(const char *s);
    int yylex();

    extern FILE* yyin;

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

	static const char *builtin_generics[] = {"list", "map", "set", "queue", "stack"};
	static int builtin_generic_count = 5;

	bool is_builtin_generic(const char *s) {
		for (int i = 0; i < builtin_generic_count; i++) {
			if (strcmp(s, builtin_generics[i]) == 0)
				return true;
		}
		return false;
	}
%}

/* things to rem : 
 * in the parser free up the memory allocated by strdup
 * check prec and associvity written below
 * */

%union{
    char* str;
    int type;
}

/* Terminals from lexer */
%token <str> INT_LITERAL REAL_LITERAL AMOUNT_LITERAL DATETIME_LITERAL STRING_LITERAL CHAR_LITERAL BOOL_LITERAL IDENTIFIER IMPORT_LIB TYPE_NAME
%token <type>  INT_T REAL_T CHAR_T STRING_T BOOL_T DATETIME_T AMOUNT_T RECORD LABEL

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

/* prec. and assoc. of ops */
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
%right UPLUS UMINUS NOT  /* unary plus, minus, logical not */
%right CAST     /* if you implement (type) ... */
%nonassoc ANGULAR_BRACKS
%left '(' ')' '[' ']' ARROW
%nonassoc NO_ELSE
%nonassoc ELSE
%left DCOLON


%%
program
	: external_declaration { printf("Matched program (single external declaration)\n"); }
	| program external_declaration { printf("Matched program (chained external declaration)\n"); }
	;

external_declaration
	: import_statement { printf("Matched external_declaration (import)\n"); }
	| macro_definition { printf("Matched external_declaration (macro)\n"); }
	| declaration { printf("Matched external_declaration (declaration)\n"); }
	| function_definition { printf("Matched external_declaration (function definition)\n"); }
	;

import_statement
	: IMPORT_LIB ';' { printf("Matched import_statement\n"); }
	;

macro_definition
	: DEFINE IDENTIFIER AS expression ';' { printf("Matched macro_definition\n"); }
	;

declaration
	: declaration_specifiers ';' { printf("Matched declaration (no init)\n"); }
	| declaration_specifiers init_declarator_list ';' { printf("Matched declaration (with init)\n"); }
	;

declaration_specifiers
    : storage_class_specifier { printf("Matched declaration_specifiers (storage only)\n"); }
    | storage_class_specifier declaration_specifiers { printf("Matched declaration_specifiers (storage and specs)\n"); }
    | type_qualifier { printf("Matched declaration_specifiers (qualifier only)\n"); }
    | type_qualifier declaration_specifiers { printf("Matched declaration_specifiers (qualifier and specs)\n"); }
    | type_specifier { printf("Matched declaration_specifiers (type only)\n"); }
    ;

storage_class_specifier
    : EXTERN { printf("Matched storage_class_specifier (extern)\n"); }
    | STATIC { printf("Matched storage_class_specifier (static)\n"); }
    ;

type_qualifier
	: CONST { printf("Matched type_qualifier (const)\n"); }
	| NONNEG { printf("Matched type_qualifier (nonneg)\n"); }
	;
type_specifier
	: INT_T { printf("Matched type_specifier (int)\n"); }
	| REAL_T { printf("Matched type_specifier (real)\n"); }
	| CHAR_T { printf("Matched type_specifier (char)\n"); }
	| STRING_T { printf("Matched type_specifier (string)\n"); }
	| BOOL_T { printf("Matched type_specifier (bool)\n"); }
	| DATETIME_T { printf("Matched type_specifier (datetime)\n"); }
	| AMOUNT_T { printf("Matched type_specifier (amount)\n"); }
	| VOID { printf("Matched type_specifier (void)\n"); }
	| user_type_specifier { printf("Matched type_specifier (user type)\n"); }
	| TYPE_NAME LT type_argument_list GT %prec ANGULAR_BRACKS
        { printf("Matched type_specifier (generic_type)\n"); }
	;

user_type_specifier 
    : record_specifier { printf("Matched user_type_specifier (record)\n"); }
	| label_specifier { printf("Matched user_type_specifier (label)\n"); }
	| TYPE_NAME{ printf("Matched user_type_specifier (identifier type)\n"); }   
    ;

type_argument_list
    : type_specifier { printf("Matched type_argument_list (single)\n"); }
    | type_argument_list ',' type_specifier { printf("Matched type_argument_list (chained)\n"); }
    ;

record_specifier
	: RECORD IDENTIFIER record_body {
	      add_type_name($2);  // now IDENTIFIER becomes a type name
	      printf("Matched record_specifier (definition with ID)\n");
	  }
	| RECORD IDENTIFIER {
	      add_type_name($2);  // forward declared type
	      printf("Matched record_specifier (declaration)\n");
	  }
	| RECORD record_body { printf("Matched record_specifier (anonymous definition)\n"); }
	;

record_body
	: '{' struct_declaration_list '}' { printf("Matched record_body\n"); }
	;

struct_declaration_list
    : struct_declaration { printf("Matched struct_declaration_list (single)\n"); }
    | struct_declaration_list struct_declaration { printf("Matched struct_declaration_list (chained)\n"); }
    ;

struct_declaration 
    : declaration { printf("Matched struct_declaration (field declaration)\n"); }
    | function_definition { printf("Matched struct_declaration (method definition)\n"); }
    ;

label_specifier
	: LABEL IDENTIFIER {
	      add_type_name($2);
	      printf("Matched label_specifier (definition/decl)\n");
	  }
	| LABEL IDENTIFIER label_body {
	      add_type_name($2);
	      printf("Matched label_specifier (definition with body)\n");
	  }
    | LABEL label_body { printf("Matched label_specifier (anonymous definition)\n"); }
    ;

label_body
    : '{' label_list '}' { printf("Matched label_body\n"); }
    ;

label_list
	: IDENTIFIER { printf("Matched label_list (single)\n"); }
	| label_list ',' IDENTIFIER { printf("Matched label_list (chained)\n"); }
	;

init_declarator_list
	: init_declarator { printf("Matched init_declarator_list (single)\n"); }
	| init_declarator_list ',' init_declarator { printf("Matched init_declarator_list (chained)\n"); }
	;

init_declarator
	: declarator { printf("Matched init_declarator (no init)\n"); }
	| declarator '=' initializer { printf("Matched init_declarator (with init)\n"); }
	;

initializer
	: assignment_expression { printf("Matched initializer (expression)\n"); }
	| '{' initializer_list '}' { printf("Matched initializer (list)\n"); }
	| '{' initializer_list ',' '}' { printf("Matched initializer (list with trailing comma)\n"); }
	;

initializer_list
	: assignment_expression { printf("Matched initializer_list (single)\n"); }
	| initializer_list ',' assignment_expression { printf("Matched initializer_list (chained)\n"); }
	;

declarator
    : IDENTIFIER   /* to-do */ { printf("Matched declarator (identifier)\n"); }
    | '(' declarator ')' { printf("Matched declarator (parenthesized)\n"); }
	| declarator '[' expression ']' { printf("Matched declarator (array index)\n"); }
	| declarator '[' ']' { printf("Matched declarator (unspecified array)\n"); }
    | declarator '(' parameter_list ')' { printf("Matched declarator (function with params)\n"); }
	/* | declarator '(' identifier_list ')' { printf("Matched declarator (function with identifiers)\n"); } */
	| declarator '('  ')' { printf("Matched declarator (function no params)\n"); }
    ;

expression
	: assignment_expression { printf("Matched expression (single assignment)\n"); }
	| expression ',' assignment_expression { printf("Matched expression (comma operator)\n"); }
	;

assignment_expression
    : logical_or_expression { printf("Matched assignment_expression (logical or)\n"); }
	| unary_expression assignment_operator assignment_expression { printf("Matched assignment_expression (compound assignment)\n"); }
	;
                                                           
assignment_operator
	: '=' { printf("Matched assignment_operator (=)\n"); }
	| MULT_ASSIGN { printf("Matched assignment_operator (*=)\n"); }
	| DIV_ASSIGN { printf("Matched assignment_operator (/=)\n"); }
	| INT_DIV_ASSIGN { printf("Matched assignment_operator (//=)\n"); }
	| MOD_ASSIGN { printf("Matched assignment_operator (%%=)\n"); }
	| PLUS_ASSIGN { printf("Matched assignment_operator (+=)\n"); }
	| MINUS_ASSIGN { printf("Matched assignment_operator (-=)\n"); }
    | POWER_ASSIGN { printf("Matched assignment_operator (^=)\n"); }
	;
                                               
logical_or_expression
	: logical_and_expression { printf("Matched logical_or_expression (and only)\n"); }
	| logical_or_expression OR logical_and_expression { printf("Matched logical_or_expression (or)\n"); }
	;

logical_and_expression
	: membership_expression { printf("Matched logical_and_expression (membership only)\n"); }
	| logical_and_expression AND membership_expression { printf("Matched logical_and_expression (and)\n"); }
	;

membership_expression
	: equality_expression { printf("Matched membership_expression (equality only)\n"); }
	| equality_expression IN equality_expression { printf("Matched membership_expression (in)\n"); }
	;

equality_expression
	: relational_expression { printf("Matched equality_expression (relational only)\n"); }
	| equality_expression EQ relational_expression { printf("Matched equality_expression (==)\n"); }
	| equality_expression NEQ relational_expression { printf("Matched equality_expression (!=)\n"); }
	| equality_expression TEQ relational_expression { printf("Matched equality_expression (===)\n"); }
	;

relational_expression
	: additive_expression { printf("Matched relational_expression (additive only)\n"); }
	| relational_expression GT additive_expression { printf("Matched relational_expression (>)\n"); }
	| relational_expression LT additive_expression { printf("Matched relational_expression (<)\n"); }
	| relational_expression GEQ additive_expression { printf("Matched relational_expression (>=)\n"); }
	| relational_expression LEQ additive_expression { printf("Matched relational_expression (<=)\n"); }
	;
    
additive_expression
	: multiplicative_expression { printf("Matched additive_expression (multiplicative only)\n"); }
	| additive_expression '+' multiplicative_expression { printf("Matched additive_expression (+)\n"); }
	| additive_expression '-' multiplicative_expression { printf("Matched additive_expression (-)\n"); }
	;

multiplicative_expression
	: exponential_expression { printf("Matched multiplicative_expression (exponential only)\n"); }
	| multiplicative_expression '*' exponential_expression { printf("Matched multiplicative_expression (*)\n"); }
	| multiplicative_expression '/' exponential_expression { printf("Matched multiplicative_expression (/)\n"); }
    | multiplicative_expression INT_DIV exponential_expression { printf("Matched multiplicative_expression (//)\n"); }
	| multiplicative_expression '%' exponential_expression { printf("Matched multiplicative_expression (%%)\n"); }
    ;

exponential_expression
    : cast_expression { printf("Matched exponential_expression (cast only)\n"); }
    | cast_expression '^' exponential_expression { printf("Matched exponential_expression (^)\n"); }
    ;

cast_expression
	: unary_expression { printf("Matched cast_expression (unary only)\n"); }
	| '(' specifier_qualifier_list ')' cast_expression  %prec CAST { printf("Matched cast_expression (explicit cast)\n"); }
    ;
    
specifier_qualifier_list
    : type_qualifier specifier_qualifier_list { printf("Matched specifier_qualifier_list (qualifier and list)\n"); }
	| type_specifier { printf("Matched specifier_qualifier_list (type only)\n"); }
    ;

unary_expression
	: postfix_expression { printf("Matched unary_expression (postfix only)\n"); }
	| '+' cast_expression %prec UPLUS { printf("Matched unary_expression (unary +)\n"); }
	| '-' cast_expression %prec UMINUS { printf("Matched unary_expression (unary -)\n"); }
	| NOT cast_expression %prec NOT { printf("Matched unary_expression (logical not)\n"); }
	;

postfix_expression
    : primary_expression { printf("Matched postfix_expression (primary)\n"); }
    | postfix_expression DCOLON IDENTIFIER { printf("Matched postfix_expression (member access ::)\n"); }
    | postfix_expression '(' ')' { printf("Matched postfix_expression (function call no args)\n"); }
    | postfix_expression '(' argument_expression_list ')' { printf("Matched postfix_expression (function call with args)\n"); }
    | postfix_expression '[' expression ']' { printf("Matched postfix_expression (subscript)\n"); }
    | postfix_expression ARROW IDENTIFIER { printf("Matched postfix_expression (member access ->)\n"); }
    ;

primary_expression
	: IDENTIFIER /* to-do */ { printf("Matched primary_expression (identifier)\n"); }
	| INT_LITERAL { printf("Matched primary_expression (int literal)\n"); }
	| REAL_LITERAL { printf("Matched primary_expression (real literal)\n"); }
	| STRING_LITERAL { printf("Matched primary_expression (string literal)\n"); }
	| CHAR_LITERAL { printf("Matched primary_expression (char literal)\n"); }
	| BOOL_LITERAL { printf("Matched primary_expression (bool literal)\n"); }
	| AMOUNT_LITERAL { printf("Matched primary_expression (amount literal)\n"); }
	| DATETIME_LITERAL { printf("Matched primary_expression (datetime literal)\n"); }
	| '(' expression ')' { printf("Matched primary_expression (parenthesized expression)\n"); }
	;


argument_expression_list
	: assignment_expression { printf("Matched argument_expression_list (single)\n"); }
	| argument_expression_list ',' assignment_expression { printf("Matched argument_expression_list (chained)\n"); }
	;

parameter_list
    : parameter_declaration { printf("Matched parameter_list (single)\n"); }
	| parameter_list ',' parameter_declaration { printf("Matched parameter_list (chained)\n"); }
	;

parameter_declaration
    : declaration_specifiers declarator { printf("Matched parameter_declaration (simple)\n"); }
    | declaration_specifiers declarator MODIFIABLE { printf("Matched parameter_declaration (modifiable)\n"); }
    | declaration_specifiers declarator DEFAULT logical_or_expression { printf("Matched parameter_declaration (default value)\n"); }
	| declaration_specifiers { printf("Matched parameter_declaration (no declarator, e.g., void)\n"); }
	;

function_definition
    : declaration_specifiers declarator compound_statement { printf("Matched function_definition\n"); }
    ;

compound_statement
    : '{' '}' { printf("Matched compound_statement (empty)\n"); }
	| '{' block_item_list '}' { printf("Matched block_item_list (statements and declarations list)\n"); } 
	; 

block_item_list
	: block_item { printf("Matched block_item_list (single)\n"); }
	| block_item_list block_item { printf("Matched block_item_list (chained)\n"); }
	;

block_item
	: declaration { printf("Matched block_item (declaration)\n"); }
	| statement { printf("Matched block_item (statement)\n"); }
	;

statement
	: compound_statement { printf("Matched statement (compound)\n"); }
	| expression_statement { printf("Matched statement (expression)\n"); }
	| selection_statement { printf("Matched statement (selection)\n"); }
	| iteration_statement { printf("Matched statement (iteration)\n"); }
	| jump_statement { printf("Matched statement (jump)\n"); }
    | exception_statement { printf("Matched statement (exception)\n"); }
	;

expression_statement
	: ';' { printf("Matched expression_statement (empty)\n"); }
	| expression ';' { printf("Matched expression_statement\n"); }
	;

selection_statement
	: IF '(' expression ')' statement %prec NO_ELSE { printf("Matched selection_statement (if)\n"); }
	| IF '(' expression ')' statement ELSE statement { printf("Matched selection_statement (if-else)\n"); }
	;

iteration_statement
	: WHILE '(' expression ')' statement { printf("Matched iteration_statement (while)\n"); }
	| FOR '(' expression_statement expression_statement ')' statement { printf("Matched iteration_statement (C-style for no update)\n"); }
	| FOR '(' expression_statement expression_statement expression ')' statement { printf("Matched iteration_statement (C-style for with update)\n"); }
	| FOR '(' type_specifier declarator FROM expression TO expression ')' statement
    { printf("Matched iteration_statement (Finex for without step)\n"); }
	| FOR '(' type_specifier declarator FROM expression TO expression STEP expression ')' statement
		{ printf("Matched iteration_statement (Finex for with step)\n"); }
    | FOR '(' type_specifier declarator IN expression ')' statement
      { printf("Matched iteration_statement (for-in typed)\n"); }
	;

jump_statement
    : CONTINUE ';' { printf("Matched jump_statement (continue)\n"); }
	| BREAK ';' { printf("Matched jump_statement (break)\n"); }
	| RETURN expression ';' { printf("Matched jump_statement (return with expression)\n"); }
	| RETURN ';' { printf("Matched jump_statement (return void)\n"); }
	;

exception_statement
	: TRY compound_statement CATCH '(' exception_declaration ')' compound_statement { printf("Matched exception_statement (try-catch)\n"); }
	| CHECK '(' expression ')' ';' { printf("Matched exception_statement (check)\n"); }
	;

exception_declaration
    : type_specifier declarator { printf("Matched exception_declaration (with declarator)\n"); }
	| type_specifier { printf("Matched exception_declaration (type only)\n"); }
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
            fprintf(stderr, "Error opening file: %s", argv[1]);
            return 1;
        }
    }
    if (yyparse() == 0) {
        printf("Parsing finished successfully.\n");
    }
    fclose(yyin);
    return 0;
}