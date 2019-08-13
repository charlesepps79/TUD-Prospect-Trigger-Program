*** READ IN THE LOAN TABLE AND KEEP ALL LOANS BOOKED THIS YEAR.    ***; 
*** MATCH THEM TO BORR TABLE ------------------------------------- ***;
LIBNAME MDRIVE 
	'\\rmc.local\dfsroot\Dept\Marketing\Analytics\snapshots';

DATA LOANS(
	keep = CIFNO orgbr BRACCTNO OWNBR CLASSID ORGST SRCD APRATE CRSCORE
		   CLASSTRANSLATION OWNST LOANDATE EFFRATE LNAMT NETLOANAMOUNT 
		   PRLNNO ORGTERM LOAN_DATE TILA_LNAMT proceeds TOT_INSPREM 
		   purcd NetNewCash pocd);
	SET DW.VW_LOAN;  
	IF SUBSTR(LOANDATE, 1, 4) = '2019';
	IF CLASSTRANSLATION = ("Retail") THEN DELETE; 
	IF INSPREM1 = . THEN INSPREM1 = 0;  
	IF INSPREM2 = . THEN INSPREM2 = 0; 
	IF INSPREM3 = . THEN INSPREM3 = 0; 
	IF INSPREM4 = . THEN INSPREM4 = 0; 
	IF INSPREM5 = . THEN INSPREM5 = 0; 
	IF INSPREM6 = . THEN INSPREM6 = 0;
	TOT_INSPREM = insprem1 + insprem2 + insprem3 + insprem4 + 
				  insprem5 + insprem6;
	LOANYR = SUBSTR(LOANDATE, 1, 4);    
	LOANMO = SUBSTR(LOANDATE, 6, 2);    
	LOANDAY = SUBSTR(LOANDATE, 9, 2);   
	LOAN_DATE = MDY(LOANMO, LOANDAY, LOANYR);
	DROP LOANYR LOANMO LOANDAY insprem1 insprem2 insprem3 insprem4 
		 insprem5 insprem6 ;
RUN;

PROC SORT;  
	BY CIFNO;
RUN;

DATA BORR(
	KEEP = CIFNO STATE LNAME FNAME SSNO SSNO_RT7 adr1 CITY zip EMAIL 
		   RENTCD SOLICIT CONFIDENTIAL CeaseandDesist);
	SET DW.VW_BORROWER;
RUN;

PROC SORT nodupkey;   
	BY CIFNO;
RUN;

DATA ALLBOOKD_2019YTD; 
	MERGE BORR(IN = INBORR) loans(IN = INLOAN);  
	BY CIFNO;  
	IF INBORR AND INLOAN;
	TRUE_CLASS = CLASSTRANSLATION;
	IF CLASSID = 65 THEN TRUE_CLASS = 'Checks';
	if CLASSTRANSLATION = 'Checks' then NETNEWCASH = tila_lnamt;
RUN;

*** how should i handle missing values for netnewcash on 1) pb,    ***;
*** 2) nb or fb? ------------------------------------------------- ***;

PROC FREQ;   
	TABLES OWNST SRCD CLASSTRANSLATION true_class PURCD loandate;
run;