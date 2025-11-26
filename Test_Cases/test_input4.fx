@accounting;

## Global Scope
int x = 100;
int y = 200;

void check_scope(int x) {
    ## 'x' here refers to the parameter (Scope 1), shadowing global 'x'
    
    if (x > 0) {
        ## Block Scope (Scope 2)
        int y = 50; ## Shadows global 'y'
        x = y;      ## Should use local 'y' (50) and param 'x'
    }
    
    ## Should refer to global 'y' (200) and param 'x'
    y = x; 
}

int main() {
    check_scope(10);
    return 0;
}