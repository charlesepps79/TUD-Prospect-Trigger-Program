LIBNAME MDRIVE 
	'\\rmc.local\dfsroot\Dept\Marketing\Analytics\SNAPSHOTS';

Proc SQL;
	Create Table AppTableQuery as
	SELECT A.AppType, A.task_refno, A.CustomerElig, A.CustomerEligDate,
		   A.CreditDenial, A.CreditDenialDate, A.CreditApproval, 
		   A.LoanNumber, A.StatusCodes, A.TaskStatus, A.LoanStatus, 
		   A.CreditScore, A.ApplicationEnterDate, A.AmountRequested, 
		   A.SmallApprovedAmount, A.LargeApprovedAmount, 
		   A.ReasonDeclined, A.FreeIncome, A.CustomerType, A.Branch, 
		   A.state, A.DTI, A.HousingStatus, A.FinalLoanAmount, 
		   A.acctrefno, A.ApplicationEnterDateOnly, A.BookDate, 
		   A.RiskRank_Small, A.RiskRank_Large, A.CustomScore, 
		   A.Monthlygrossincome, A.Cifno
	FROM DW.vw_AppData A
	where A.ApplicationEnterDateOnly BETWEEN 
		  '2019-07-13' AND '2019-08-13';
RUN;

PROC SORT;  
	BY CIFNO;
RUN;

Proc SQL;
	Create Table TradesAndBk as
	SELECT
		p.Cifno,
		p.ReportDate,
		p.TotalTradeLines, 
		b.DateFiled,
		b.DateReported
	FROM
		NLSPROD.creditprofile  p
		INNER JOIN (
			SELECT 
				Cifno, 
				MAX(ReportDate) AS MaxReportDate 
			FROM NLSPROD.creditprofile 
			GROUP BY Cifno) md 
			ON p.Cifno = md.Cifno AND p.ReportDate = MaxReportDate
		LEFT JOIN NLSPROD.creditbankruptcy b 
			ON p.CreditProfileID = b.CreditProfileID;
RUN;

PROC SORT nodupkey;  
	BY CIFNO;
RUN;

DATA appsTradesAndBk; 
	MERGE AppTableQuery(IN = INAPPS) TradesAndBk(IN = INTRADES);  
	BY CIFNO;  
	IF INAPPS;
RUN;

DATA APPS(
	KEEP = TASK_REFNO TASKSTATUS CUSTOMERELIG CREDITAPPROVAL 
		   CUSTOMERTYPE LOANNUMBER ApplicationEnterDateonly APPYR APPMM 
		   APPDAY ApplicationEnterDate FREEINCOME MONTHLYGROSSINCOME 
		   DTI_RATIO DTI CREDITSCORE CUSTOMSCORE CUSTOM_SCORE 
		   REASONDECLINED HOUSINGSTATUS RISKRANK_SMALL RISKRANK_LARGE 
		   STATE METHOD REASON Cifno TotalTradeLines DateFiled 
		   DateReported);
   *set MDRIVE.TEMPAPPS_20190706; *0615;  *0419; 	
	set appsTradesAndBk;  *08;

	*** EXCLUSIONS ----------------------------------------------- ***;
	IF TASKSTATUS = 'VOIDED' then DELETE;

	*** MITCH SAYS THESE ARE ONLY LEADS, NOT APPS ---------------- ***;
	IF TASKSTATUS in ('NEW LEAD' 'LEAD INACTIVE') 
		then delete; 

	DTI_RATIO = DTI * 1;
	CUSTOM_SCORE = CUSTOMSCORE * 1;
	*** CREATE WATERFALL OF EXCLUSION REASONS... ----------------- ***;
	REASON = '99. KEEP THE APPLICATION';

	IF CUSTOMERTYPE = 'PB' 
		THEN REASON = '1. PB APP'; 
	ELSE 
	IF LOANNUMBER NE '' 
		THEN REASON = '2. BOOKED LOAN'; 
   *ELSE
	If CUSTOMERELIG NE 'ELIGIBLE' 
		THEN REASON = '3. NOT SYSTEM ELIGIBLE'; 
	ELSE 
	If substr(CREDITAPPROVAL, 1, 6) = 'DENIED' 
		THEN REASON = '3. CR APPRVL = DENIED'; 
	ELSE 
	if taskstatus = 'DENIED' 
		THEN REASON = '4. TASK STATUS = DENIED'; 
	ELSE 
	IF riskrank_small = 'FAIL' 
		THEN REASON = '5. RISK RANK FAIL'; 
   *ELSE 
	IF riskrank_small IN ('WEAK' 'FAIL') 
		THEN REASON = '6. RISK RANK WEAK/FAIL'; 
   *ELSE 
	If CUSTOMERELIG NE 'ELIGIBLE' and (CUSTOM_SCORE < 240 or 
									   CREDITSCORE < 575 )   
		THEN REASON = '7. INELIG, FICO OR CUST LOW'; 
	ELSE 
	if taskstatus NOT IN ('CANCELED', 'WITHDRAWN') 
		THEN REASON = '6. NOT WITHDR or CANCELED'; 
	ELSE
	IF CREDITAPPROVAL NE 'APPROVED' 
		THEN REASON = '8. NOT BR APPROVED OR DENIED'; 

	If  SUBSTR(REASON, 1, 2) IN ('8.' '99') AND 
		CUSTOMERELIG NE 'ELIGIBLE' 
		THEN DO;
  		if CUSTOM_SCORE ge 270 AND CREDITSCORE ge 575 
			THEN REASON = '9. INELIG, MAYBE';
  		else 
		if CUSTOM_SCORE ge 240 AND CREDITSCORE ge 600    
			THEN REASON = '9. INELIG, MAYBE';
  		else reason = '7. INELIGIBLE, LOW SCORE';
	END;

	*** FORMAT SOME FIELDS (CONVERT FROM CHARACTER TO NUMERIC OR   ***;
	*** TRIM EXTRA CHARACTERS, MAKE DATE FIELDS DATE FORMAT FOR    ***;
	*** DATE MATH ETC). MAKE RISK RANKS SORTABLE ----------------- ***;
	IF reasondeclined = '' 
		THEN reasondeclined = 'MISSING';

	APPYR = SUBSTR(ApplicationEnterDateonly, 1, 4);    
	APPMM = SUBSTR(ApplicationEnterDateonly, 6, 2);    
	APPDAY = SUBSTR(ApplicationEnterDateonly, 9, 2);   
	ApplicationEnterDate = MDY(APPMM, APPDAY, APPYR);

   *IF '30jun2019'd < ApplicationEnterDate < '01aug2019'd;
   *IF '08jul2019'd < ApplicationEnterDate < '09aug2019'd;

	*** CLEAN UP SOME BAD STATE FORMATS -------------------------- ***;
	IF STATE IN ('AL' 'OK' 'NM' 'NC' 'GA' 'TN' 'MO' 'WI' 'SC' 'TX' 'VA' 
				 'WI') 
		THEN STATE = STATE;  
	ELSE DO;
  		IF STATE IN ('AL.' 'ALA') 
			THEN STATE = 'AL'; 
		ELSE 
  		IF STATE = 'AZ' 
			THEN STATE = 'NM'; 
		ELSE 
  		IF STATE = 'FL' 
			THEN STATE = 'GA'; 
		ELSE 
  		IF SUBSTR(STATE, 1, 1) = 'G' 
			THEN STATE = 'GA'; 
		ELSE 
  		IF STATE = 'KS' 
			THEN STATE = 'MO'; 
		ELSE 
  		IF STATE  ='TEX' 
			THEN STATE = 'TX'; 
		ELSE 
  		IF STATE = 'TX.' 
			THEN STATE = 'TX'; 
		ELSE 
  		IF STATE = 'WI.' 
			THEN STATE = 'WI';
  		ELSE STATE = '??';
	END;

	DROP APPYR APPMM APPDAY LOANNUMBER CUSTOMSCORE DTI 
		 ApplicationEnterDate;
RUN;

PROC FREQ;
	TABLES REASON;
RUN;

proc freq;  
	tables creditapproval taskstatus riskrank_small reasondeclined; 
	WHERE SUBSTR(REASON, 1, 2) = '9.';
RUN;

proc freq;
	tables reasondeclined * riskrank_small / NOCOL NOROW NOPERCENT; 
	WHERE SUBSTR(REASON, 1, 2) = '9.';
RUN;

DATA KEEPERS;
	format task_refno ApplicationEnterDateOnly taskstatus housingstatus 
		   customertype reasondeclined creditscore custom_score 
		   riskrank_small riskrank_large freeincome monthlygrossincome 
		   dti_ratio customerelig creditapproval STATE Cifno 
		   TotalTradeLines DateFiled DateReported;
	SET APPS;
	WHERE SUBSTR(REASON, 1, 2) IN ('8.' '99');
	DROP LOANNUMBER APPYR APPMM APPDAY METHOD ApplicationEnterDate DTI 
		 CUSTOMSCORE REASON;
RUN;

PROC SORT;  
	BY ApplicationEnterDateonly;
RUN;

*** THESE NEED TO BE CHECKED AGAINST NLS FIELDS TO SEE IF THEY     ***;
*** HAVE > TRADE AND DON'T HAVE A RECENT BK ---------------------- ***;
DATA INELIG;   
	format task_refno ApplicationEnterDateOnly taskstatus housingstatus 
		   customertype reasondeclined creditscore custom_score 
		   riskrank_small riskrank_large freeincome monthlygrossincome 
		   dti_ratio customerelig creditapproval STATE Cifno 
		   TotalTradeLines DateFiled DateReported;
	SET APPS;
	WHERE SUBSTR(REASON, 1, 2) = '9.';  
RUN;
