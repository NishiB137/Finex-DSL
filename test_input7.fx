int main() {
    int x = 10      ## Error 1: Missing semicolon
    int y = 20;     ## Should be parsed correctly due to recovery
    return 0;
}