## 1. Global Constants (Macros)
define INITIAL_CAPITAL as 100000.0;
define TRANSACTION_FEE as 10.0;
define STOP_LOSS_THRESHOLD as 0.05;

## 2. Type Aliasing
using real as Price;
using real as Quantity;

## 3. Enums for Trade Logic
label Side { BUY, SELL };
label Status { OPEN, CLOSED, REJECTED };

## 4. Data Structures
record Asset {
    string ticker;
    Price currentPrice;
    real volatility;
};

record Trade {
    string id;
    string ticker;
    Side side;
    Quantity qty;
    Price executionPrice;
};

record Portfolio {
    string owner;
    Price cashBalance;
    real totalValue;
    Status accountStatus;
};

## 5. Helper Function: Calculate Transaction Cost
real calculateCost(Quantity q, Price p) {
    real rawCost = q * p;
    return rawCost + TRANSACTION_FEE;
}

## 6. Core Logic: Execute a Trade (Modifies Portfolio)
void executeOrder(Portfolio pf modifiable, Trade t) {
    ## strict check
    check(t->qty > 0.0);
    
    real totalCost = calculateCost(t->qty, t->executionPrice);

    if (t->side == Side::BUY) {
        if (pf->cashBalance >= totalCost) {
            pf->cashBalance = pf->cashBalance - totalCost;
            pf->totalValue = pf->totalValue + (t->qty * t->executionPrice);
        } else {
            throw "Insufficient funds for BUY order";
        }
    } 
    else {
        ## Logic for SELL
        pf->cashBalance = pf->cashBalance + (totalCost - (2.0 * TRANSACTION_FEE));
        pf->totalValue = pf->totalValue - (t->qty * t->executionPrice);
    }
}

## 7. Simulation Loop
void runBacktest(Portfolio pf modifiable, list<Trade> tradeList) {
    ## Custom For-In Loop
    for (Trade t in tradeList) {
        
        ## Nested Scope with Shadowing
        real riskFactor = 0.0;
        
        if (t->executionPrice > 1000.0) {
            real riskFactor = 0.1; ## High value trade risk
            if (riskFactor > STOP_LOSS_THRESHOLD) {
                ## Skip risky trades
                continue; 
            }
        }
        
        executeOrder(pf, t);
    }
    
    ## Final Valuation Update
    if (pf->cashBalance < 0.0) {
        pf->accountStatus = Status::REJECTED;
    } else {
        pf->accountStatus = Status::CLOSED;
    }
}

## 8. Main Entry Point
int main() {
    ## Initialization
    Portfolio myFund = { "QuantFund_A", INITIAL_CAPITAL, 0.0, Status::OPEN };
    
    ## Setup Mock Trades
    Trade t1 = { "T1", "AAPL", Side::BUY, 50.0, 150.0 };
    Trade t2 = { "T2", "GOOG", Side::BUY, 10.0, 2800.0 };
    Trade t3 = { "T3", "AAPL", Side::SELL, 20.0, 155.0 };
    
    list<Trade> history = { t1, t2, t3 };
    
    ## Execution Block
    try {
        runBacktest(myFund, history);
        
        check(myFund->cashBalance > 0.0);
        
    } catch (string errorMsg) {
        ## Error handling logic
        myFund->accountStatus = Status::REJECTED;
    }
}