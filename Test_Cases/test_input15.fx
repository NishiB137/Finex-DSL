record Point {
    int x;
    int y;
}

int add_score(int base, int bonus) {
    return base + bonus;
}

## [Error 1] Return Type Mismatch
int bad_return() {
    return "Wrong Type"; 
}

int main() {
    Point p;
    p.x = 10;
    p.y = 20;

    ## [Error 2] Member Access: Member 'z' does not exist
    p.z = 30;

    ## 1. Valid Function Call
    int s = add_score(100, 50);

    ## [Error 3] Argument Count Mismatch
    int f = add_score(100);

    ## [Error 4] Argument Type Mismatch
    int g = add_score(100, "Bonus");

    return 0;
}