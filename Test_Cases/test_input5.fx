@accounting;

int score = 10;
## ERROR 1: Global Redeclaration
int score = 20; 

void calculate(int val) {
    int result = val * 2;
    
    ## ERROR 2: Local Redeclaration
    int result = 0; 

    ## ERROR 3: Undeclared Identifier (z is never defined)
    result = z + 1;
}

int main() {
    return 0;
}