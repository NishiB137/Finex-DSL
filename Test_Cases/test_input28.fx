## 1. System Constants
define MAX_PRICE_DEVIATION as 0.10;
define MIN_ORDER_QTY as 100.0;
define MAX_ORDER_QTY as 100000.0;

## 2. Type Definitions
using real as Price;
using real as Volume;
using int as OrderId;

## 3. Enumerations
label Side { BUY, SELL, SHORT };
label Type { MARKET, LIMIT, STOP };
label State { NEW, REJECTED, FILLED, PARTIAL };

## 4. Complex Records
record Order {
    OrderId id;
    Side side;
    Type type;
    Price limitPrice;
    Volume qty;
    State status;
};

record MarketSnapshot {
    Price lastTradedPrice;
    Volume totalVolume;
    Price vwap; ## Volume Weighted Average Price
};

## 5. VWAP Calculation Helper (Math heavy)
Price calculateNewVWAP(MarketSnapshot market, Price tradePrice, Volume tradeQty) {
    real currentTotalVal = market->vwap * market->totalVolume;
    real newTradeVal = tradePrice * tradeQty;
    
    real newTotalVol = market->totalVolume + tradeQty;
    
    if (newTotalVol == 0.0) {
        return 0.0;
    }
    
    return (currentTotalVal + newTradeVal) / newTotalVol;
}

## 6. Order Validation Logic (Deep Nesting)
void validateAndFill(Order ord modifiable, MarketSnapshot mkt modifiable) {
    ## Check Quantity Limits
    if (ord->qty < MIN_ORDER_QTY) {
        ord->status = State::REJECTED;
        throw "Order quantity below minimum threshold";
    }
    
    if (ord->qty > MAX_ORDER_QTY) {
        ord->status = State::REJECTED;
        return; ## Silent rejection for large orders
    }

    ## Check Price Deviation for Limit Orders
    if (ord->type == Type::LIMIT) {
        real deviation = 0.0;
        
        if (ord->limitPrice > mkt->lastTradedPrice) {
            deviation = (ord->limitPrice - mkt->lastTradedPrice) / mkt->lastTradedPrice;
        } else {
            deviation = (mkt->lastTradedPrice - ord->limitPrice) / mkt->lastTradedPrice;
        }

        if (deviation > MAX_PRICE_DEVIATION) {
            ord->status = State::REJECTED;
            return;
        }
    }

    ## Simulate Fill
    ord->status = State::FILLED;
    
    ## Update Market State
    mkt->vwap = calculateNewVWAP(mkt, ord->limitPrice, ord->qty);
    mkt->totalVolume = mkt->totalVolume + ord->qty;
    mkt->lastTradedPrice = ord->limitPrice;
}

## 7. Batch Processor
void processBatch(list<Order> batch, MarketSnapshot mkt modifiable) {
    ## Custom For-In Loop
    for (Order o in batch) {
        try {
            validateAndFill(o, mkt);
        } catch (string err) {
            ## Log error logic would go here
            o->status = State::REJECTED;
        }
    }
}

## 8. Main Execution
int main() {
    ## Initialize Market State
    MarketSnapshot currentMarket = { 150.0, 500000.0, 149.50 };
    
    ## Create Order Batch
    Order o1 = { 101, Side::BUY, Type::LIMIT, 155.0, 500.0, State::NEW };   ## Valid
    Order o2 = { 102, Side::SELL, Type::MARKET, 148.0, 50.0, State::NEW };  ## Too small (Throws)
    Order o3 = { 103, Side::BUY, Type::LIMIT, 200.0, 1000.0, State::NEW };  ## High deviation (Rejects)
    
    list<Order> incomingBatch = { o1, o2, o3 };
    
    check(currentMarket->totalVolume > 0.0);

    processBatch(incomingBatch, currentMarket);
    
    ## Assertions
    check(currentMarket->totalVolume > 500000.0);
}