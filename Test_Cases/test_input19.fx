## Function to calculate risk, throws error on zero volatility
real calculateSharpeRatio(real returnVal, real riskFree, real volatility) {
    if (volatility == 0.0) {
        throw "Division by zero: Volatility cannot be zero";
    }
    return (returnVal - riskFree) / volatility;
}

int main() {
    real ret = 0.12;
    real rf = 0.04;
    real vol = 0.0; 
    
    try {
        check(ret > rf); ## Semantic check: Assertion
        real sharpe = calculateSharpeRatio(ret, rf, vol);
    } catch (string errMsg) {
        ## Error handling logic
        real sharpe = 0.0;
    }
}