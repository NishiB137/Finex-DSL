## ==========================================
## Finex Comprehensive Error Test Case
## Covers: Semicolons, Types, Control Flow,
##         Expressions, Functions, Exceptions
## ==========================================

## [Error 1] Global Scope: Missing semicolon after import
@accounting 

## [Error 2] Global Scope: Missing semicolon in type alias
using int as Integer

## [Error 3] Record Definition: Missing semicolon inside struct member
record Client {
    string name;
    int id          ## Missing ';' here
    amount balance;
}

## [Error 4] Function Def: Missing comma in parameter list
int calculate_risk(int score int age) {
    return score * age;
}

int main() {
    ## [Error 5] Declaration: Using a keyword 'for' as an identifier
    int for = 20;

    ## [Error 6] Declaration: Unknown/Invalid Lexer Token '$'
    ## The lexer update should flag this and return it to parser
    amount salary = $5000USD;

    ## [Error 7] Declaration: Missing semicolon
    real tax_rate = 0.15

    ## [Error 8] Expression: Malformed operators (consecutive binary ops)
    int value = 100 * / 5;

    ## [Error 9] Control Flow: IF statement missing parentheses around condition
    ## Grammar requires: IF '(' expression ')'
    if tax_rate > 0.10 {
        print("High tax");
    }

    ## [Error 10] Control Flow: Malformed FOR loop
    ## Mixing C-style syntax with Range syntax incorrectly
    for (int i from 0; i < 10; i = i + 1) {
        print(i);
    }

    ## [Error 11] Exception Handling: Catch block missing variable name
    ## Grammar requires: catch (type name) OR catch (type)
    try {
        check(value > 0);
    } catch (string) {   ## This might actually be valid depending on your grammar rule 2!
        print("Error");
    }
    
    ## [Error 12] Exception Handling: Invalid Catch syntax
    try {
        throw "Error";
    } catch {            ## Grammar requires parens and arguments
        print("Recovering");
    }

    ## [Error 13] Unbalanced Parentheses in expression
    int logic_fail = (5 + 10 * 2;

    return 0;
}