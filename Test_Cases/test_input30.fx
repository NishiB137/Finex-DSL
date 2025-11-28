void print(string msg) {}

int main() {
    ## Declare variables first
    int a = 10;
    int b = 20;
    int c = 5;

    ## First level check
    if (a > 5) {
        
        ## Second level check (Nested)
        if (b > 15) {
            
            ## Third level check (Deeply Nested)
            if (c == 5) {
                print("Condition met: a > 5, b > 15, and c == 5");
            } else {
                print("Condition met: a > 5, b > 15, but c != 5");
            }

        } else {
            ## Else for second level
            print("Condition met: a > 5 but b <= 15");
        }

    } else {
        ## Else for first level
        if (a == 0) {
            print("a is zero");
        } else {
            print("a is less than or equal to 5 and not zero");
        }
    }

    return 0;
}