record Point {
    int x;
    int y;
}; 

int add_score(int base, int bonus) {
    return base + bonus;
}

## [Semantic Error 1] Return Type Mismatch (String vs Int)
int bad_return() {
    return "Wrong Type"; 
}

int main() {
    Point p;
    
    ## [Fix 2] Used '->' instead of '.'
    p->x = 10;
    p->y = 20;

    ## [Semantic Error 2] Member Access: Member 'z' does not exist
    p->z = 30;

    ## 1. Valid Function Call
    int s = add_score(100, 50);

    ## [Semantic Error 3] Argument Count Mismatch
    int f = add_score(100);

    ## [Semantic Error 4] Argument Type Mismatch
    int g = add_score(100, "Bonus");

    return 0;
}