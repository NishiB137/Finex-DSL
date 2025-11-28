record Asset {
    string symbol;
    real value;
    real beta;
};

record Portfolio {
    string id;
    list<Asset> assets;
    real totalValue;
};

void stressTest(Portfolio p modifiable, real marketShock) {
    real projectedLoss = 0.0;
    
    ## Custom for-in loop syntax
    for (Asset a in p->assets) {
        ## Calculate drop based on Beta
        real drop = a->value * a->beta * marketShock;
        
        ## Apply shock
        a->value = a->value - drop;
        projectedLoss += drop;
    }
    
    p->totalValue = p->totalValue - projectedLoss;
}

int main() {
    Asset a1 = { "SPY", 10000.0, 1.0 };
    Asset a2 = { "TSLA", 5000.0, 1.5 };
    
    list<Asset> holdings = { a1, a2 };
    Portfolio p = { "PF001", holdings, 15000.0 };
    
    stressTest(p, 0.10); ## 10% market crash simulation
}