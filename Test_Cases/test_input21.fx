label MarketState { BULLISH, BEARISH, SIDEWAYS };
label Signal { BUY, SELL, HOLD };

record MarketData {
    real currentPrice;
    real movingAvg50;
    real movingAvg200;
    real rsi;
};

Signal getSignal(MarketData data, MarketState state) {
    ## Golden Cross condition
    bool goldenCross = (data->movingAvg50 > data->movingAvg200);
    
    if (state == MarketState::BULLISH and goldenCross and data->rsi < 70.0) {
        return Signal::BUY;
    } 
    else if (state == MarketState::BEARISH or data->rsi > 80.0) {
        return Signal::SELL;
    }
    
    return Signal::HOLD;
}

int main() {
    MarketData md = { 150.5, 145.0, 140.0, 65.0 };
    Signal s = getSignal(md, MarketState::BULLISH);
}