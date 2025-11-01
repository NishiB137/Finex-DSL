@accounting;

## Simple function definition
int add(int x, int y) {
    return x + y;
}

## Record definition 
record Account {
    int id;
    amount balance;
    string name;
};

## Label definition
label Status { Active, Inactive, Pending }; 

## Variable declarations
int count = 10;
real price = 99.99;
amount money = 100.50USD;

## Main function
int main() {
    int result;
    result = add(5, 3);
    
    ## If statement
    if (result > 0) {
        result = result + 1;
    } else {
        result = 0;
    }
    
    ## While loop
    int i = 0;
    while (i < 10) {
        i = i + 1;
    }
    
    ## For loop 
    for (int j from 0 to 10 step 2) {
        j = j + 1;
    }
    
    ## Function call
    int sum = add(result, i);
    
    return sum;
}