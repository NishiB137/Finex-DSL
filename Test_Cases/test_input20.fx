record Date {
    int year;
    int month;
    int day;
};

record Shareholder {
    string id;
    string name;
    int shareCount;
    bool eligible;
};

record Dividend {
    string ticker;
    real amountPerShare;
    Date payDate;
};

void processPayment(Shareholder holder, Dividend div) {
    check(holder->shareCount > 0);
    
    if (holder->eligible == false) {
        throw "Shareholder not eligible for dividend";
    }

    real totalPayout = (real)div->amountPerShare * holder->shareCount;
}

int main() {
    Date d = { 2025, 12, 01 };
    Dividend div = { "MSFT", 0.75, d };
    Shareholder sh = { "SH99", "Alice Corp", 5000, true };

    try {
        processPayment(sh, div);
    } catch (string error) {
        ## Log error (simulated)
    }
}