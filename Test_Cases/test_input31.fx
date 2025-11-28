using real as Price;

record Item {
    string name;
    Price cost;
};

## 1. Function expecting modifiable L-Value
void updatePrice(Price p modifiable) {
    p = p + 10.0;
}

## 2. Void function trying to return a value
void logError() {
    return 100; ## ERROR: Void function returns value
}

int main() {
    int count = 10;
    Price currentPrice = 50.0;
    Item myItem = { "Widget", 50.0 };

    ## 3. Loop Context Error
    if (count > 5) {
        break; ## ERROR: Break outside loop
    }

    ## 4. Boolean Condition Error
    if (currentPrice) { ## ERROR: Condition must be bool (currentPrice is real)
        count = count + 1;
    }

    ## 5. L-Value Error (Modifiable)
    updatePrice(100.0); ## ERROR: Argument 1 must be L-Value (passing literal)

    ## 6. Type Mismatch (Assignment)
    count = 50.5; ## ERROR: Cannot assign real to int

    ## 7. Subscript Error (Non-Array)
    real val = currentPrice[0]; ## ERROR: Subscript on non-list type

    ## 8. Subscript Error (Bad Index)
    list<int> numbers = {1, 2, 3};
    int x = numbers[10.5]; ## ERROR: Index must be integer

    ## 9. Argument Count Error
    updatePrice(currentPrice, 10.0); ## ERROR: Incorrect argument count

    ## 10. Invalid Binary Op
    string s = "Hello" - "World"; ## ERROR: Invalid binary operation
}