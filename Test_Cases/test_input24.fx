record Bond {
    real faceValue;
    real couponRate;
    int yearsToMaturity;
};

real calculateDuration(Bond b, real yield) {
    real weightedTime = 0.0;
    real totalPV = 0.0;
    int t = 1;
    
    while (t <= b->yearsToMaturity) {
        real cashFlow = 0.0;
        if (t == b->yearsToMaturity) {
            cashFlow = b->faceValue * (1.0 + b->couponRate);
        } else {
            cashFlow = b->faceValue * b->couponRate;
        }
        
        real pv = cashFlow / ((1.0 + yield) ^ t);
        
        weightedTime += (real)t * pv;
        totalPV += pv;
        
        t += 1;
    }
    
    return weightedTime / totalPV;
}

int main() {
    Bond b = { 1000.0, 0.05, 5 };
    real duration = calculateDuration(b, 0.04);
}