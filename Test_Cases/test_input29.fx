## 1. Financial Constants
define MIN_CREDIT_SCORE as 650;
define MAX_DTI_RATIO as 0.40;  ## Max Debt-to-Income Ratio
define BASE_INTEREST_RATE as 0.05;

## 2. Domain Types
using int as Score;
using real as Rate;
using real as Money;

## 3. Enumerations
label EmpType { SALARIED, SELF_EMPLOYED, RETIRED };
label LoanStatus { PENDING, APPROVED, REJECTED, REVIEW };

## 4. Nested Data Structures
record Applicant {
    string name;
    Score creditScore;
    EmpType employment;
    Money annualIncome;
    Money currentDebt;
};

record LoanApplication {
    int id;
    Applicant applicant;
    Money requestedAmount;
    int termMonths;
    LoanStatus status;
    Rate approvedRate;
};

## 5. Helper: Calculate Monthly Debt-to-Income (DTI)
real calculateDTI(Applicant p, Money newEmi) {
    real monthlyIncome = p->annualIncome / 12.0;
    
    ## Protect against division by zero
    if (monthlyIncome == 0.0) {
        return 1.0; ## 100% DTI (Bad)
    }

    real monthlyDebt = (p->currentDebt / 12.0) + newEmi;
    return monthlyDebt / monthlyIncome;
}

## 6. Business Logic: Process Loan
void processLoan(LoanApplication app modifiable) {
    Applicant person = app->applicant;

    ## Rule 1: Knockout Rule (Credit Score)
    if (person->creditScore < MIN_CREDIT_SCORE) {
        app->status = LoanStatus::REJECTED;
        return;
    }

    ## Rule 2: Interest Rate Determination
    Rate finalRate = BASE_INTEREST_RATE;
    
    if (person->employment == EmpType::SELF_EMPLOYED) {
        finalRate = finalRate + 0.02; ## Risk premium
    }

    if (person->creditScore > 750) {
        finalRate = finalRate - 0.01; ## Good credit discount
    }

    ## Rule 3: Affordability Check (DTI)
    ## Estimated Monthly Installment (Simplified Interest)
    real totalInterest = app->requestedAmount * finalRate * (real)(app->termMonths / 12);
    real estimatedEmi = (app->requestedAmount + totalInterest) / (real)app->termMonths;

    real dti = calculateDTI(person, estimatedEmi);

    if (dti > MAX_DTI_RATIO) {
        throw "Debt-to-Income ratio exceeds limit";
    }

    ## Approval
    app->approvedRate = finalRate;
    app->status = LoanStatus::APPROVED;
}

## 7. Batch Processing Engine
void batchProcessor(list<LoanApplication> loans) {
    ## Iterate through applications
    for (LoanApplication app in loans) {
        
        ## Skip already processed ones
        if (app->status != LoanStatus::PENDING) {
            continue;
        }

        try {
            processLoan(app);
        } catch (string reason) {
            ## On error (like High DTI), mark for manual review
            app->status = LoanStatus::REVIEW;
        }
    }
}

## 8. Main Execution
int main() {
    ## Setup Applicants
    Applicant alice = { "Alice", 780, EmpType::SALARIED, 120000.0, 5000.0 };
    Applicant bob = { "Bob", 600, EmpType::RETIRED, 40000.0, 0.0 };
    Applicant charlie = { "Charlie", 700, EmpType::SELF_EMPLOYED, 80000.0, 40000.0 }; ## High Debt

    ## Create Applications
    LoanApplication la1 = { 101, alice, 500000.0, 60, LoanStatus::PENDING, 0.0 };
    LoanApplication la2 = { 102, bob, 10000.0, 12, LoanStatus::PENDING, 0.0 };
    LoanApplication la3 = { 103, charlie, 300000.0, 36, LoanStatus::PENDING, 0.0 };

    list<LoanApplication> batch = { la1, la2, la3 };

    batchProcessor(batch);

    ## Validations
    check(la1->status == LoanStatus::APPROVED);
    check(la2->status == LoanStatus::REJECTED); ## Low Score
    check(la3->status == LoanStatus::REVIEW);   ## High DTI Exception
}