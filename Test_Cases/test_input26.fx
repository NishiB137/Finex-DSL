using real as Money;
using int as AccountId;

record Account {
    AccountId id;
    Money balance;
    bool isFrozen;
};

void transfer(Account fromAcc modifiable, Account toAcc modifiable, Money amountVal) {
    check(amountVal > 0.0);
    
    if (fromAcc->isFrozen or toAcc->isFrozen) {
        throw "Account is frozen";
    }

    if (fromAcc->balance >= amountVal) {
        fromAcc->balance = fromAcc->balance - amountVal;
        toAcc->balance = toAcc->balance + amountVal;
    } else {
        throw "Insufficient funds";
    }
}

int main() {
    Account alice = { 101, 5000.0, false };
    Account bob = { 102, 100.0, false };
    
    try {
        transfer(alice, bob, 200.0);
    } catch (string err) {
        ## Handle error
    }
}