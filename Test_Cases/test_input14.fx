int main() {
    ## 1. Valid Declarations
    int count = 10;
    real price = 99.99;
    string name = "Finex";
    
    ## 2. Valid Implicit Promotion (int -> real)
    ## The analyzer should allow this because int promotes to real
    real total = price + count; 

    ## 3. [Error] Type Mismatch: Assigning String to Int
    int invalid_assign = "Hello";

    ## 4. [Error] Type Mismatch: Binary Operation
    ## Cannot multiply a real number by a string
    real bad_calc = price * name;

    ## 5. [Error] Undeclared Identifier
    ## 'tax_rate' has not been declared yet
    real final_cost = price * tax_rate;

    ## 6. [Error] Variable Redeclaration
    ## 'count' was already declared at the top of this scope
    int count = 20;

    ## 7. Scope Check (Block)
    if (total > 100.0) {
        int block_var = 5;
    }
    
    ## 8. [Error] Out of Scope Access
    ## 'block_var' is local to the if-block above
    int fail_scope = block_var;

    return 0;
}