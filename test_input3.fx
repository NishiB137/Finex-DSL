@accounting;

## 1. Type Aliasing (using ... as ...)
using int as Score;
using amount as Balance;

## 2. Function using the aliased type 'Score'
Score validate_score(Score s) {
    if (s < 0) {
        ## 3. Throw statement
        throw "Score cannot be negative";
    }
    return s;
}

## Function using aliased type 'Balance'
void check_funds(Balance b) {
    if (b < 10.00USD) {
        throw "Insufficient funds";
    }
}

int main() {
    ## Using the alias in variable declaration
    Score current_score = 10;
    
    try {
        validate_score(current_score);
        check_funds(5.00USD);
    } catch (string err) {
        ## Handle error
        current_score = 0;
    }

    return 0;
}
