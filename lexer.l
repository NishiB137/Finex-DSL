%{
    #include<stdio.h>
    #include<string.h>
    #include<stdbool.h>
    #include "y.tab.h"

    int columnno = 0;
    void count();
    extern bool is_builtin_generic(const char *s);
    extern bool is_type_name(const char *s);
%}

%option yylineno
%option nounput

INT        [0-9]+
REAL       ([0-9]+[eE][+-]?[0-9]+)|(([0-9]*\.[0-9]+|[0-9]+\.[0-9]*)([eE][+-]?[0-9]+)?)
ID         [a-zA-Z_][a-zA-Z0-9_]*
STRING     \"([^\"\n]|\\.)*\"
CHAR       \'([^\'\n]|\\.)\' 
DATETIME   \{[0-9]{4}-[0-9]{2}-[0-9]{2},[0-9]{2}:[0-9]{2}:[0-9]{2}\}
CURRENCY    (USD|EUR|INR|GBP|JPY|AUD|CAD|CHF|CNY)
IMPORT_LIB  @(accounting|datastream|containers|statmodel)

%%
"int"              { count(); yylval.type = INT_T; return INT_T; }
"real"             { count(); yylval.type = REAL_T; return REAL_T; }
"char"             { count(); yylval.type = CHAR_T; return CHAR_T; }
"string"           { count(); yylval.type = STRING_T; return STRING_T; }
"bool"             { count(); yylval.type = BOOL_T; return BOOL_T; }
"datetime"         { count(); yylval.type = DATETIME_T; return DATETIME_T; }
"amount"           { count(); yylval.type = AMOUNT_T; return AMOUNT_T; }
"record"           { count(); yylval.type = RECORD; return RECORD; }    
"label"            { count(); yylval.type = LABEL; return LABEL; }
"if"               { count(); return IF; }
"else"             { count(); return ELSE; }
"for"              { count(); return FOR; }
"while"            { count(); return WHILE; }
"try"              { count(); return TRY; }
"catch"            { count(); return CATCH; }
"throw"            { count(); return THROW; }
"check"            { count(); return CHECK; }
"from"             { count(); return FROM; }
"to"               { count(); return TO; }
"step"             { count(); return STEP; }
"modifiable"       { count(); return MODIFIABLE; }
"default"          { count(); return DEFAULT; }
"as"               { count(); return AS; }
"return"           { count(); return RETURN; }
"void"             { count(); return VOID; }
"break"            { count(); return BREAK; }
"continue"         { count(); return CONTINUE; }
"const"            { count(); return CONST; }
"nonneg"           { count(); return NONNEG; }
"extern"           { count(); return EXTERN; }
"static"           { count(); return STATIC; }
"using"            { count(); return USING; }  
"define"            { count(); return DEFINE; }
"true"             { count(); yylval.str = strdup(yytext); return BOOL_LITERAL; }
"false"            { count(); yylval.str = strdup(yytext); return BOOL_LITERAL; }
"+"                { count(); return ('+'); }
"-"                { count(); return ('-'); }
"*"                { count(); return ('*'); }
"/"                { count(); return ('/'); }
"//"               { count(); return INT_DIV; }
"%"                { count(); return ('%'); }
"^"                { count(); return ('^'); }

"="                { count(); return ('='); }
"+="               { count(); return PLUS_ASSIGN; }
"-="               { count(); return MINUS_ASSIGN; }
"*="               { count(); return MULT_ASSIGN; }
"/="               { count(); return DIV_ASSIGN; }
"//="               { count(); return INT_DIV_ASSIGN; }
"%="               { count(); return MOD_ASSIGN; }
"^="               { count(); return POWER_ASSIGN; }

"=="               { count(); return EQ; }
"!="               { count(); return NEQ; }
"==="              { count(); return TEQ; }
">"                { count(); return GT; }
"<"                { count(); return LT; }
">="               { count(); return GEQ; }
"<="               { count(); return LEQ; }

"and"              { count(); return AND; }
"or"               { count(); return OR; }
"not"              { count(); return NOT; }
"in"               { count(); return IN; }
"->"               { count(); return ARROW; }
"{"                { count(); return ('{'); }
"}"                { count(); return ('}'); }
"("                { count(); return ('('); }
")"                { count(); return (')'); }
"["                { count(); return ('['); }
"]"                { count(); return (']'); }
";"                { count(); return (';'); }
","                { count(); return (','); }
":"                { count(); return (':'); }
"::"               { count(); return DCOLON; }

{IMPORT_LIB}       { count(); yylval.str = strdup(yytext); return IMPORT_LIB; }
{DATETIME}         { count(); yylval.str = strdup(yytext); return DATETIME_LITERAL; }
{REAL}             { count(); yylval.str = strdup(yytext); return REAL_LITERAL; }
{INT}              { count(); yylval.str = strdup(yytext); return INT_LITERAL; }
({REAL}|{INT}){CURRENCY}         { count(); yylval.str = strdup(yytext); return AMOUNT_LITERAL; }
{STRING}           { count(); yylval.str = strdup(yytext); return STRING_LITERAL; }
{CHAR}             { count(); 
                    /*
                    if (yytext[1] == '\\') { 
                        switch (yytext[2]) { 
                            case 'n':  yylval = "\n"; break;
                            case 't':  yylval = "\t"; break;
                            case 'r':  yylval = "\r"; break;
                            case '\'': yylval = "\'"; break;
                            case '\\': yylval = "\\"; break;
                            default:   strcpy(yylval, yytext+1, strlen(yytext)-2); break;
                        }
                    } else {
                        yylval = yytext[1];
                    }
                    */
                    yylval.str = strdup(yytext); 
                    return CHAR_LITERAL;
                    }
{ID}        {
                count(); yylval.str = strdup(yytext);
                if (is_builtin_generic(yytext) || is_type_name(yytext)) {
                    return TYPE_NAME;
                } else {
                    return IDENTIFIER;
                }
            }


[ \t\r\n]+                  { count(); }
\/\#([^\#]|\#+[^\/])*\#\/   { count(); }    /* multi line comments */
"##".* { count(); }   /* single line*/
.                           { printf("Unknown token: %s at line %d, column %d\n", yytext, yylineno, columnno); }
%%


void count()
{
	int i;
	for (i = 0; yytext[i] != '\0'; i++)
		if (yytext[i] == '\n')
			columnno = 0;
		else if (yytext[i] == '\t')
			columnno += 8 - (columnno % 8);
		else
			columnno++;
}

int yywrap(){
    return 1;
}