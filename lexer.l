%{
    #include<stdio.h>
    #include<stdlib.h>
    #include<string.h>
    // #include"y.tab.h"
%}

INT        [0-9]+
REAL       [0-9]+\.[0-9]+([eE][+-]?[0-9]+)?
ID         [a-zA-Z_][a-zA-Z0-9_]*
STRING     \"([^\"\n]|\\.)*\"
CHAR       \'([^\'\n]|\\.)\'
DATE       [0-9]{4}"-"[0-9]{2}"-"[0-9]{2}
TIME       [0-9]{2}":"[0-9]{2}":"[0-9]{2}
DATETIME   {DATE}","{TIME}
CURRENCY    (USD|EUR|INR|GBP|JPY|AUD|CAD|CHF|CNY)
AMOUNT      {REAL}{CURRENCY}

%%
"int"              { return INT_T; }
"real"             { return REAL_T; }
"char"             { return CHAR_T; }
"string"           { return STRING_T; }
"bool"             { return BOOL_T; }
"datetime"         { return DATETIME_T; }
"amount"           { return AMOUNT_T; }
"record"           { return RECORD; }
"label"            { return LABEL; }
"abstract"         { return ABSTRACT; }
"extends"          { return EXTENDS; }
"list"             { return LIST; }
"map"              { return MAP; }
"multimap"         { return MULTIMAP; }
"set"              { return SET; }
"multiset"         { return MULTISET; }
"stack"            { return STACK; }
"queue"            { return QUEUE; }
"dequeue"          { return DEQUEUE; }
"priority_queue"   { return PRIORITY_QUEUE; }
"function"         { return FUNCTION; }
"if"               { return IF; }
"else"             { return ELSE; }
"for"              { return FOR; }
"while"            { return WHILE; }
"return"           { return RETURN; }
"true"             { yylval.boolval = 1; return BOOL_CONST; }
"false"            { yylval.boolval = 0; return BOOL_CONST; }

"+"                { return PLUS; }
"-"                { return MINUS; }
"*"                { return MULT; }
"/"                { return DIV; }
"//"               { return INT_DIV; }
"%"                { return MOD; }
"^"                { return POWER; }

"="                { return ASSIGN; }
"+="               { return PLUS_ASSIGN; }
"-="               { return MINUS_ASSIGN; }
"*="               { return MULT_ASSIGN; }
"/="               { return DIV_ASSIGN; }
"%="               { return MOD_ASSIGN; }
"^="               { return POWER_ASSIGN; }

"=="               { return EQ; }
"!="               { return NEQ; }
">"                { return GT; }
"<"                { return LT; }
">="               { return GEQ; }
"<="               { return LEQ; }

"and"              { return AND; }
"or"               { return OR; }
"not"              { return NOT; }
"in"               { return IN; }
"->"               { return ARROW; }
"{"                { return LBRACE; }
"}"                { return RBRACE; }
"("                { return LPAREN; }
")"                { return RPAREN; }
"["                { return LBRACKET; }
"]"                { return RBRACKET; }
";"                { return SEMICOLON; }
","                { return COMMA; }
":"                { return COLON; }
"::"               { return DCOLON; }
"."                { return DOT; }

{AMOUNT}           { yylval.strval = strdup(yytext); return AMOUNT_LITERAL; }
{DATETIME}         { yylval.strval = strdup(yytext); return DATETIME_LITERAL; }
{REAL}             { yylval.realval = atof(yytext); return REAL_LITERAL; }
{INT}              { yylval.intval = atoi(yytext); return INT_LITERAL; }
{STRING}           { yylval.strval = strdup(yytext); return STRING_LITERAL; }
{CHAR}             { yylval.charval = yytext[1]; return CHAR_LITERAL; }
{ID}               { yylval.strval = strdup(yytext); return IDENTIFIER; }

[ \t\r\n]+         ;
"#".*              ;
.                  { printf("Unknown token: %s\n", yytext); }
%%

int yywrap(){
    return 1;
}
int main(){
    yyin=fopen("program.fin", "r");
    if(!yyin){
        perror("fopen");
        exit(EXIT_FAILURE);
    }
    yylex();
    fclose(yyin);
    return 0;
}
