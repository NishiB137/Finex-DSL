int main() {
    int a = 1       ## Error 1: Missing semi
    
    int b = 2;      ## Valid line (should be parsed if recovery works)
    
    while (b > ) {  ## Error 2: Missing expression before ')'
        b = b - 1;
    }
    
    return 0;
}