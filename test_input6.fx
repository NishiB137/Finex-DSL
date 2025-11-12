int main() {
    ## Call 'calculate_tax' BEFORE it is defined.
    ## This works because Pass 1 collects all function names first.
    int tax = calculate_tax(100);
    return 0;
}

int calculate_tax(int amt) {
    return amt / 10;
}