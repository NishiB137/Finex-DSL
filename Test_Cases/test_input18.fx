record Asset {
    string symbol;
    real quantity;
    real purchasePrice;
};

record Portfolio {
    string ownerName;
    list<Asset> holdings;
    real cashBalance;
};

int main() {
    Asset a1 = { "AAPL", 50.0, 150.25 };
    Asset a2 = { "GOOGL", 10.0, 2800.50 };
    
    list<Asset> myAssets = { a1, a2 };
    
    Portfolio myPortfolio = { "John Doe", myAssets, 10000.0 };
    
    ## Semantic check: Member access
    real firstQty = a1->quantity;
}