## 1. Global Variable
int g_val = 100;

## 2. Forward Reference / Mutual Recursion
## Pass 1 collects 'even' and 'odd'. Pass 2 checks bodies.
int is_even(int n) {
    if (n == 0) { return 1; }
    return is_odd(n - 1);  ## Calls function defined *below*
}

int is_odd(int n) {
    if (n == 0) { return 0; }
    return is_even(n - 1);
}

## 3. Void Function
void logger() {
    ## Just returns nothing
    return;
}

int main() {
    ## -----------------------------------------
    ## VALID OPERATIONS
    ## -----------------------------------------
    
    ## Recursion Test (Renamed variable to 'result' to avoid keyword collision)
    int result = is_even(10);

    ## Shadowing Test
    if (result > 0) {
        ## This 'g_val' shadows the global one (Scope nesting)
        int g_val = 50; 
        
        ## Should use local (50), not global (100)
        int local_calc = g_val + 10; 
    }
    return 0;
}