int salary = 1000USD; 
@invalid_library;


int x = 10
real y = 20.0;

string while = "loop";

## This lacks a type (int/void/etc) before the name.
myFunction(int a) {
    return a;
}


record BrokenStruct {
    int id;
    string name;
## Missing '}' here

void badLoop() {
    for (int i = 0, i < 10, i = i + 1) {
        print(i);
    }
}

void badRange() {
    for (int i from 0 10) { 
        ## logic
    }
}


void badIf() {
    if (x > ) {
        x = 0;
    }
}

void badTry() {
    try {
        throw "Error";
    } catch string e {
        ## ...
    }
}

void mathError() {
    real val = 5.0 + * 10.0;
}