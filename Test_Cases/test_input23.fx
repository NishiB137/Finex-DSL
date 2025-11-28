define RISK_FREE_RATE as 0.04;
define VOLATILITY as 0.20;

record Option {
    string type; 
    real strike;
    real expiryYears;
};

real priceOption(Option opt, real spotPrice, real rate) {
    real d1 = (spotPrice - opt->strike) / (opt->strike * rate);
    
    if (opt->type == "Call") {
        return d1 * 10.0; 
    } else {
        return d1 * 5.0;
    }
}

int main() {
    Option callOpt = { "Call", 100.0, 1.0 };
    
    real p1 = priceOption(callOpt, 105.0, RISK_FREE_RATE);
    
    real p2 = priceOption(callOpt, 105.0, 0.05);
}