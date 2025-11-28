using real as ExchangeRate;
using real as Money;

record CurrencyPair {
    string base;
    string quote;
    ExchangeRate rate;
};

Money convert(Money amountInBase, CurrencyPair pair) {
    check(pair->rate > 0.0);
    return amountInBase * pair->rate;
}

int main() {
    CurrencyPair eurUsd = { "EUR", "USD", 1.10 };
    
    Money euros = 500.0;
    Money dollars = convert(euros, eurUsd);
    
    check(dollars > euros);
}