USE [bodb02]
GO
 
ALTER  PROCEDURE [dbo].[Lrf_Rpt_WinlostRacing]
	@LicenseeID    INT ,
	@UserID		INT,
    @LicenseeType  VARCHAR(100) = NULL ,
    @CurrencyID    INT=0 ,
	@winlostdate	DATETIME
AS 
/*
	Created by: Henry
	Date: 2011-09-21
	Task: Racing Detailed Report 
	DB: DBRPT/BODB02
	
	Revisions:
		 -- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		 -- 20120731@Jim: add PlayerComm value 
		 -- 20121004@Jim: replace @currencyname input param by @currencyID
         -- 20130124@Daniel: Change link server alias		 
		 -- 20130403@Jim: support base currency USD
		 -- 20130618@Jim: Restrict permission of Licensee Users by currency	
		 -- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		 - 20150123@Jim: support base on Currency GBP
		 - 20160413@Victor: support MKK currency code
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @MoveBetsDay SMALLDATETIME, @wldate DATETIME
	SELECT    
		 @MoveBetsDay=MAX(eventdate)  
	FROM match14 WITH(NOLOCK)  

	SELECT @wldate=@winlostdate
	
	SELECT CurrencyID
		  ,LicenseeID
		  INTO #Currency
	FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE  usrID=@userID 
		AND LicenseeID=@LicenseeID 
		AND SystemID=1
		AND isActive=1
		AND (@CurrencyID =0 OR (CurrencyID=@CurrencyID ))
	
	DECLARE @Temp   AS TABLE (LicenseeId INT,CustId INT,Currency INT,Description VARCHAR(100) )	
	DECLARE @TempAg AS TABLE ( CustId INT, Currency INT )
	DECLARE @sql VARCHAR(500)
	SELECT  @sql =  'SELECT LicenseeId,CustID,Currency,Description FROM  OPENQUERY(DBLIC, ''SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')'
	
	INSERT INTO @Temp  (LicenseeId  ,CustId  ,Currency  ,Description )
	EXEC (@sql)
	
	INSERT  INTO @TempAg(CustId,Currency )
	SELECT    CustID  
			,Currency
	FROM     @Temp lc
			INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
	WHERE   (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
			 AND [Description] = COALESCE(@LicenseeType,  
										 [Description])  
---------------------------
DROP TABLE #Currency
---------------------------
IF @wldate > @MoveBetsDay 	
BEGIN
	SELECT	
			CASE WHEN e.exchangeid = 51 THEN 'INH' WHEN e.exchangeid = 70 THEN 'MKK' ELSE e.Code END as currencyname,
			currency,
			leagueid,
			groupmatch,
			ISNULL(hr.winTOMem,0)					winTOMem,
			ISNULL(hr.winTOMemMYR,0)				winTOMemMYR,
			ISNULL(hr.winTOMem * e.EUR,0)				winTOMemEUR,
			ISNULL(hr.winTOMem * e.USD,0)				winTOMemUSD,
			ISNULL(hr.winTOMem * e.GBP,0)				winTOMemGBP,
			
			ISNULL(hr.placeTOMem,0)					placeTOMem,
			ISNULL(hr.placeTOMemMYR,0)				placeTOMemMYR,
			ISNULL(hr.placeTOMem * e.EUR,0)				placeTOMemEUR,
			ISNULL(hr.placeTOMem * e.USD,0)				placeTOMemUSD,
			ISNULL(hr.placeTOMem * e.GBP,0)				placeTOMemGBP,
			
			ISNULL(hr.winplaceTOMem,0)				winplaceTOMem,
			ISNULL(hr.winplaceTOMemMYR,0)			winplaceTOMemMYR,
			ISNULL(hr.winplaceTOMem * e.EUR,0)			winplaceTOMemEUR,
			ISNULL(hr.winplaceTOMem * e.USD,0)			winplaceTOMemUSD,
			ISNULL(hr.winplaceTOMem * e.GBP,0)			winplaceTOMemGBP,
			
			ISNULL(hr.winTOMem,0)
			  + ISNULL(hr.placeTOMem,0)
			  + ISNULL(hr.winplaceTOMem,0)			totalTOMem,			
			  
			ISNULL(hr.winTOMemMYR,0) 
			  + ISNULL(hr.placeTOMemMYR,0)
			  + ISNULL(hr.winplaceTOMemMYR,0)	totalTOMemMYR,
			
			ISNULL(hr.winTOMem * e.EUR,0) 
			  + ISNULL(hr.placeTOMem * e.EUR,0)
			  + ISNULL(hr.winplaceTOMem * e.EUR,0)	totalTOMemEUR,
			  ---
			  ISNULL(hr.winTOMem * e.USD,0) 
			  + ISNULL(hr.placeTOMem * e.USD,0)
			  + ISNULL(hr.winplaceTOMem * e.USD,0)	totalTOMemUSD,
			 ---
			 ---
			  ISNULL(hr.winTOMem * e.GBP,0) 
			  + ISNULL(hr.placeTOMem * e.GBP,0)
			  + ISNULL(hr.winplaceTOMem * e.GBP,0)	totalTOMemGBP,	
			  
			ISNULL(hr.DividendWonMem,0)				DividendWonMem,	
			ISNULL(hr.DividendWonMemMYR,0)		DividendWonMemMYR,
			ISNULL(hr.DividendWonMem * e.EUR,0)		DividendWonMemEUR,
			ISNULL(hr.DividendWonMem * e.USD,0)		DividendWonMemUSD,--
			ISNULL(hr.DividendWonMem * e.GBP,0)		DividendWonMemGBP,--
			
			ISNULL(hr.winTOLicensee,0)				winTOLicensee,
			ISNULL(hr.winTOLicenseeMYR,0)		winTOLicenseeMYR,
			ISNULL(hr.winTOLicensee * e.EUR,0)		winTOLicenseeEUR,
			ISNULL(hr.winTOLicensee * e.USD,0)		winTOLicenseeUSD,
			ISNULL(hr.winTOLicensee * e.GBP,0)		winTOLicenseeGBP,
			
			ISNULL(hr.placeTOLicensee,0)			placeTOLicensee,
			ISNULL(hr.placeTOLicenseeMYR,0)		placeTOLicenseeMYR,
			ISNULL(hr.placeTOLicensee * e.EUR,0)		placeTOLicenseeEUR,
			ISNULL(hr.placeTOLicensee * e.USD,0)		placeTOLicenseeUSD,
			ISNULL(hr.placeTOLicensee * e.GBP,0)		placeTOLicenseeGBP,
			
			ISNULL(hr.winplaceTOLicensee,0)			winplaceTOLicensee,
			ISNULL(hr.winplaceTOLicenseeMYR,0)	winplaceTOLicenseeMYR,
			ISNULL(hr.winplaceTOLicensee * e.EUR,0)	winplaceTOLicenseeEUR,
			ISNULL(hr.winplaceTOLicensee * e.USD,0)	winplaceTOLicenseeUSD,
			ISNULL(hr.winplaceTOLicensee * e.GBP,0)	winplaceTOLicenseeGBP,
			
			ISNULL(hr.winTOLicensee,0)
				+ ISNULL(hr.placeTOLicensee,0)
				+ ISNULL(hr.winplaceTOLicensee,0)		totalTOLicensee,
			ISNULL(hr.winTOLicenseeMYR,0)
				+ ISNULL(hr.placeTOLicenseeMYR,0)
				+ ISNULL(hr.winplaceTOLicenseeMYR,0) totalTOLicenseeMYR,	
			
			ISNULL(hr.winTOLicensee * e.EUR,0)
				+ ISNULL(hr.placeTOLicensee* e.EUR,0)
				+ ISNULL(hr.winplaceTOLicensee* e.EUR,0) totalTOLicenseeEUR,	
			---
			ISNULL(hr.winTOLicensee * e.USD,0)
				+ ISNULL(hr.placeTOLicensee* e.USD,0)
				+ ISNULL(hr.winplaceTOLicensee* e.USD,0) totalTOLicenseeUSD,	
				---
			ISNULL(hr.winTOLicensee * e.GBP,0)
				+ ISNULL(hr.placeTOLicensee* e.GBP,0)
				+ ISNULL(hr.winplaceTOLicensee* e.GBP,0) totalTOLicenseeGBP,
				
			ISNULL(PTWLLicensee,0)					PTWLLicensee,	
			ISNULL(PTWLLicenseeMYR,0)				PTWLLicenseeMYR,
			ISNULL(PTWLLicensee * e.EUR,0)				PTWLLicenseeEUR,
			ISNULL(PTWLLicensee * e.USD,0)				PTWLLicenseeUSD,
			ISNULL(PTWLLicensee * e.GBP,0)				PTWLLicenseeGBP,
			
			ISNULL(hr.commIncomeLicensee,0)			commIncomeLicensee,
			ISNULL(hr.commIncomeLicenseeMYR,0)	commIncomeLicenseeMYR,		
			ISNULL(hr.commIncomeLicensee * e.EUR,0)	commIncomeLicenseeEUR,		
			ISNULL(hr.commIncomeLicensee * e.USD,0)	commIncomeLicenseeUSD,
			ISNULL(hr.commIncomeLicensee * e.GBP,0)	commIncomeLicenseeGBP,
			ISNULL(hr.PlayercommIncomeLicensee,0)		PlayercommIncomeLicensee,
			ISNULL(hr.PlayercommIncomeLicenseeMYR,0)	PlayercommIncomeLicenseeMYR,
			ISNULL(hr.PlayercommIncomeLicensee*e.EUR,0)	PlayercommIncomeLicenseeEUR,
			ISNULL(hr.PlayercommIncomeLicensee*e.USD,0)	PlayercommIncomeLicenseeUSD,
			ISNULL(hr.PlayercommIncomeLicensee*e.GBP,0)	PlayercommIncomeLicenseeGBP,
 			ISNULL(hr.winTOMem,0)
			  + ISNULL(hr.placeTOMem,0)
			  + ISNULL(hr.winplaceTOMem,0)
			  - ISNULL(hr.DividendWonMem,0)
			  - ISNULL(hr.PTWLLicensee,0)
			  - ISNULL(hr.commIncomeLicensee,0)		AmountDueToRB,	
			ISNULL(hr.winTOMemMYR,0)
			  + ISNULL(hr.placeTOMemMYR,0)
			  + ISNULL(hr.winplaceTOMemMYR,0)
			  - ISNULL(hr.DividendWonMemMYR,0)
			  - ISNULL(hr.PTWLLicenseeMYR,0)
			  - ISNULL(hr.commIncomeLicenseeMYR,0)AmountDueToRBMYR,
			ISNULL(hr.winTOMem* e.EUR,0)
			  + ISNULL(hr.placeTOMem* e.EUR,0)
			  + ISNULL(hr.winplaceTOMem* e.EUR,0)
			  - ISNULL(hr.DividendWonMem* e.EUR,0)
			  - ISNULL(hr.PTWLLicensee* e.EUR,0)
			  - ISNULL(hr.commIncomeLicensee* e.EUR,0)AmountDueToRBEUR,
			ISNULL(hr.winTOMem* e.USD,0)
			  + ISNULL(hr.placeTOMem* e.USD,0)
			  + ISNULL(hr.winplaceTOMem* e.USD,0)
			  - ISNULL(hr.DividendWonMem* e.USD,0)
			  - ISNULL(hr.PTWLLicensee* e.USD,0)
			  - ISNULL(hr.commIncomeLicensee* e.USD,0)AmountDueToRBUSD,
			--
			ISNULL(hr.winTOMem* e.GBP,0)
			  + ISNULL(hr.placeTOMem* e.GBP,0)
			  + ISNULL(hr.winplaceTOMem* e.GBP,0)
			  - ISNULL(hr.DividendWonMem* e.GBP,0)
			  - ISNULL(hr.PTWLLicensee* e.GBP,0)
			  - ISNULL(hr.commIncomeLicensee* e.GBP,0) AmountDueToRBGBP		
	FROM (
			SELECT	o.leagueid,
					o.groupmatch,
					b.currency,
					-- Turnover Member 
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake ELSE 0 END) winTOMem,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake ELSE 0 END) placeTOMem,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE b.liveawayscore WHEN 0 THEN b.actual_stake/2 ELSE b.actual_stake END) ELSE 0 END) winplaceTOMem,
					
					-- Turnover Member MYR
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake*b.actualrate ELSE 0 END) winTOMemMYR,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake*b.actualrate ELSE 0 END) placeTOMemMYR,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE b.liveawayscore WHEN 0 THEN b.actual_stake/2 ELSE b.actual_stake END)*b.actualrate ELSE 0 END) winplaceTOMemMYR,

					-- DividendWon Member 
					SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN b.winlost -b.actual_stake/2 ELSE b.winlost END) DividendWonMem,
					-- DividendWon Member MYR
					SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN (b.winlost -b.actual_stake/2)*b.actualrate ELSE b.winlost*b.actualrate END) DividendWonMemMYR,
					
					--Turnover Licensee
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake*b.tpositiontaking ELSE 0 END) winTOLicensee,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake*b.tpositiontaking ELSE 0 END) placeTOLicensee,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE WHEN b.liveawayscore = 0 THEN b.actual_stake/2 ELSE b.actual_stake END)*b.tpositiontaking ELSE 0 END) winplaceTOLicensee,
					--Turnover Licensee MYR
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake*b.tpositiontaking*b.actualrate ELSE 0 END) winTOLicenseeMYR,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake*b.tpositiontaking*b.actualrate ELSE 0 END) placeTOLicenseeMYR,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE WHEN b.liveawayscore = 0 THEN b.actual_stake/2 ELSE b.actual_stake END)*b.tpositiontaking*b.actualrate ELSE 0 END) winplaceTOLicenseeMYR,
					-- commission Licensee 	
					SUM(b.comm ) commIncomeLicensee,
					SUM((b.comm )*b.actualrate) commIncomeLicenseeMYR,
					SUM(b.PlayerComm ) PlayercommIncomeLicensee,
					SUM(b.PlayerComm *b.actualrate) PlayercommIncomeLicenseeMYR,
					
					--PT Winloss Licensee 
					SUM(b.awinlost + b.mwinlost + b.swinlost) PTWLLicensee,
					SUM((b.awinlost + b.mwinlost + b.swinlost)*b.actualrate) PTWLLicenseeMYR
			FROM	bettrans b WITH (NOLOCK,index=CIX_matchid_bettype) 
					INNER JOIN Outright o WITH (NOLOCK) ON b.matchid = o.orid 
					INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.currency = ag.currency
			WHERE	b.winlostdate = @wldate 
					AND b.bettype in (31,32,33)
					AND b.statusID NOT IN (101,102,103,121)
					AND b.ruben = 1
					AND b.matchid > 0
			GROUP BY o.leagueid, o.groupmatch, b.currency
	)hr
	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@wldate,@wldate))e 
	ON  hr.currency = e.exchangeid
	ORDER BY currencyName, leagueid, CAST (groupmatch AS TINYINT)
END
ELSE
BEGIN
	SELECT	
			CASE WHEN e.exchangeid = 51 THEN 'INH' WHEN e.exchangeid = 70 THEN 'MKK' ELSE e.Code END as currencyname,
			currency,
			leagueid,
			groupmatch,
			ISNULL(hr.winTOMem,0)					winTOMem,
			ISNULL(hr.winTOMemMYR,0)				winTOMemMYR,
			ISNULL(hr.winTOMem * e.EUR,0)				winTOMemEUR,
			ISNULL(hr.winTOMem * e.USD,0)				winTOMemUSD,
			ISNULL(hr.winTOMem * e.GBP,0)				winTOMemGBP,
			
			ISNULL(hr.placeTOMem,0)					placeTOMem,
			ISNULL(hr.placeTOMemMYR,0)				placeTOMemMYR,
			ISNULL(hr.placeTOMem * e.EUR,0)				placeTOMemEUR,
			ISNULL(hr.placeTOMem * e.USD,0)				placeTOMemUSD,
			ISNULL(hr.placeTOMem * e.GBP,0)				placeTOMemGBP,
			
			ISNULL(hr.winplaceTOMem,0)				winplaceTOMem,
			ISNULL(hr.winplaceTOMemMYR,0)			winplaceTOMemMYR,
			ISNULL(hr.winplaceTOMem * e.EUR,0)			winplaceTOMemEUR,
			ISNULL(hr.winplaceTOMem * e.USD,0)			winplaceTOMemUSD,
			ISNULL(hr.winplaceTOMem * e.GBP,0)			winplaceTOMemGBP,
			
			ISNULL(hr.winTOMem,0)
			  + ISNULL(hr.placeTOMem,0)
			  + ISNULL(hr.winplaceTOMem,0)			totalTOMem,			
			  
			ISNULL(hr.winTOMemMYR,0) 
			  + ISNULL(hr.placeTOMemMYR,0)
			  + ISNULL(hr.winplaceTOMemMYR,0)	totalTOMemMYR,
			
			ISNULL(hr.winTOMem * e.EUR,0) 
			  + ISNULL(hr.placeTOMem * e.EUR,0)
			  + ISNULL(hr.winplaceTOMem * e.EUR,0)	totalTOMemEUR,
			 
			ISNULL(hr.winTOMem * e.USD,0) 
			  + ISNULL(hr.placeTOMem * e.USD,0)
			  + ISNULL(hr.winplaceTOMem * e.USD,0)	totalTOMemUSD,
			 --
			ISNULL(hr.winTOMem * e.GBP,0) 
			  + ISNULL(hr.placeTOMem * e.GBP,0)
			  + ISNULL(hr.winplaceTOMem * e.GBP,0)	totalTOMemGBP,
			  
			ISNULL(hr.DividendWonMem,0)				DividendWonMem,	
			ISNULL(hr.DividendWonMemMYR,0)		DividendWonMemMYR,
			ISNULL(hr.DividendWonMem * e.EUR,0)		DividendWonMemEUR,
			ISNULL(hr.DividendWonMem * e.USD,0)		DividendWonMemUSD,
			ISNULL(hr.DividendWonMem * e.GBP,0)		DividendWonMemGBP,
			
			ISNULL(hr.winTOLicensee,0)				winTOLicensee,
			ISNULL(hr.winTOLicenseeMYR,0)		winTOLicenseeMYR,
			ISNULL(hr.winTOLicensee * e.EUR,0)		winTOLicenseeEUR,
			ISNULL(hr.winTOLicensee * e.USD,0)		winTOLicenseeUSD,
			ISNULL(hr.winTOLicensee * e.GBP,0)		winTOLicenseeGBP,
			
			ISNULL(hr.placeTOLicensee,0)			placeTOLicensee,
			ISNULL(hr.placeTOLicenseeMYR,0)		placeTOLicenseeMYR,
			ISNULL(hr.placeTOLicensee * e.EUR,0)		placeTOLicenseeEUR,
			ISNULL(hr.placeTOLicensee * e.USD,0)		placeTOLicenseeUSD,
			ISNULL(hr.placeTOLicensee * e.GBP,0)		placeTOLicenseeGBP,
			
			ISNULL(hr.winplaceTOLicensee,0)			winplaceTOLicensee,
			ISNULL(hr.winplaceTOLicenseeMYR,0)	winplaceTOLicenseeMYR,
			ISNULL(hr.winplaceTOLicensee * e.EUR,0)	winplaceTOLicenseeEUR,
			ISNULL(hr.winplaceTOLicensee * e.USD,0)	winplaceTOLicenseeUSD,
			ISNULL(hr.winplaceTOLicensee * e.GBP,0)	winplaceTOLicenseeGBP,
			
			ISNULL(hr.winTOLicensee,0)
				+ ISNULL(hr.placeTOLicensee,0)
				+ ISNULL(hr.winplaceTOLicensee,0)		totalTOLicensee,
			ISNULL(hr.winTOLicenseeMYR,0)
				+ ISNULL(hr.placeTOLicenseeMYR,0)
				+ ISNULL(hr.winplaceTOLicenseeMYR,0) totalTOLicenseeMYR,	
			
			ISNULL(hr.winTOLicensee * e.EUR,0)
				+ ISNULL(hr.placeTOLicensee* e.EUR,0)
				+ ISNULL(hr.winplaceTOLicensee* e.EUR,0) totalTOLicenseeEUR,	
			
			ISNULL(hr.winTOLicensee * e.USD,0)
				+ ISNULL(hr.placeTOLicensee* e.USD,0)
				+ ISNULL(hr.winplaceTOLicensee* e.USD,0) totalTOLicenseeUSD,
			ISNULL(hr.winTOLicensee * e.GBP,0)
				+ ISNULL(hr.placeTOLicensee* e.GBP,0)
				+ ISNULL(hr.winplaceTOLicensee* e.GBP,0) totalTOLicenseeGBP,
				
			ISNULL(PTWLLicensee,0)					PTWLLicensee,	
			ISNULL(PTWLLicenseeMYR,0)				PTWLLicenseeMYR,
			ISNULL(PTWLLicensee * e.EUR,0)				PTWLLicenseeEUR,
			ISNULL(PTWLLicensee * e.USD,0)				PTWLLicenseeUSD,
			ISNULL(PTWLLicensee * e.GBP,0)				PTWLLicenseeGBP,
			
			ISNULL(hr.commIncomeLicensee,0)			commIncomeLicensee,
			ISNULL(hr.commIncomeLicenseeMYR,0)	commIncomeLicenseeMYR,		
			ISNULL(hr.commIncomeLicensee * e.EUR,0)	commIncomeLicenseeEUR,
			ISNULL(hr.commIncomeLicensee * e.USD,0)	commIncomeLicenseeUSD,
			ISNULL(hr.commIncomeLicensee * e.GBP,0)	commIncomeLicenseeGBP,
			ISNULL(hr.PlayercommIncomeLicensee,0)		PlayercommIncomeLicensee,	
			ISNULL(hr.PlayercommIncomeLicenseeMYR,0)	PlayercommIncomeLicenseeMYR,
			ISNULL(hr.PlayercommIncomeLicensee*e.EUR,0)	PlayercommIncomeLicenseeEUR,
			ISNULL(hr.PlayercommIncomeLicensee*e.USD,0)	PlayercommIncomeLicenseeUSD,
			ISNULL(hr.PlayercommIncomeLicensee*e.GBP,0)	PlayercommIncomeLicenseeGBP,
			
 			ISNULL(hr.winTOMem,0)
			  + ISNULL(hr.placeTOMem,0)
			  + ISNULL(hr.winplaceTOMem,0)
			  - ISNULL(hr.DividendWonMem,0)
			  - ISNULL(hr.PTWLLicensee,0)
			  - ISNULL(hr.commIncomeLicensee,0)		AmountDueToRB,	
			ISNULL(hr.winTOMemMYR,0)
			  + ISNULL(hr.placeTOMemMYR,0)
			  + ISNULL(hr.winplaceTOMemMYR,0)
			  - ISNULL(hr.DividendWonMemMYR,0)
			  - ISNULL(hr.PTWLLicenseeMYR,0)
			  - ISNULL(hr.commIncomeLicenseeMYR,0)AmountDueToRBMYR,
			ISNULL(hr.winTOMem* e.EUR,0)
			  + ISNULL(hr.placeTOMem* e.EUR,0)
			  + ISNULL(hr.winplaceTOMem* e.EUR,0)
			  - ISNULL(hr.DividendWonMem* e.EUR,0)
			  - ISNULL(hr.PTWLLicensee* e.EUR,0)
			  - ISNULL(hr.commIncomeLicensee* e.EUR,0)AmountDueToRBEUR,
			 ISNULL(hr.winTOMem* e.USD,0)
			  + ISNULL(hr.placeTOMem* e.USD,0)
			  + ISNULL(hr.winplaceTOMem* e.USD,0)
			  - ISNULL(hr.DividendWonMem* e.USD,0)
			  - ISNULL(hr.PTWLLicensee* e.USD,0)
			  - ISNULL(hr.commIncomeLicensee* e.USD,0)AmountDueToRBUSD ,
			 ISNULL(hr.winTOMem* e.GBP,0)
			  + ISNULL(hr.placeTOMem* e.GBP,0)
			  + ISNULL(hr.winplaceTOMem* e.GBP,0)
			  - ISNULL(hr.DividendWonMem* e.GBP,0)
			  - ISNULL(hr.PTWLLicensee* e.GBP,0)
			  - ISNULL(hr.commIncomeLicensee* e.GBP,0)AmountDueToRBGBP  

	FROM (
			SELECT	o.leagueid,
					o.groupmatch,
					b.currency,
					-- Turnover Member 
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake ELSE 0 END) winTOMem,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake ELSE 0 END) placeTOMem,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE b.liveawayscore WHEN 0 THEN b.actual_stake/2 ELSE b.actual_stake END) ELSE 0 END) winplaceTOMem,
					
					-- Turnover Member MYR
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake*b.actualrate ELSE 0 END) winTOMemMYR,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake*b.actualrate ELSE 0 END) placeTOMemMYR,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE b.liveawayscore WHEN 0 THEN b.actual_stake/2 ELSE b.actual_stake END)*b.actualrate ELSE 0 END) winplaceTOMemMYR,

					-- DividendWon Member 
					SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN b.winlost -b.actual_stake/2 ELSE b.winlost END) DividendWonMem,
					-- DividendWon Member MYR
					SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN (b.winlost -b.actual_stake/2)*b.actualrate ELSE b.winlost*b.actualrate END) DividendWonMemMYR,
					
					--Turnover Licensee
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake*b.tpositiontaking ELSE 0 END) winTOLicensee,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake*b.tpositiontaking ELSE 0 END) placeTOLicensee,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE WHEN b.liveawayscore = 0 THEN b.actual_stake/2 ELSE b.actual_stake END)*b.tpositiontaking ELSE 0 END) winplaceTOLicensee,
					--Turnover Licensee MYR
					SUM(CASE WHEN b.bettype = 31 THEN b.actual_stake*b.tpositiontaking*b.actualrate ELSE 0 END) winTOLicenseeMYR,
					SUM(CASE WHEN b.bettype = 32 THEN b.actual_stake*b.tpositiontaking*b.actualrate ELSE 0 END) placeTOLicenseeMYR,
					SUM(CASE WHEN b.bettype = 33 THEN (CASE WHEN b.liveawayscore = 0 THEN b.actual_stake/2 ELSE b.actual_stake END)*b.tpositiontaking*b.actualrate ELSE 0 END) winplaceTOLicenseeMYR,
					-- commission Licensee 	
					SUM(b.comm ) commIncomeLicensee,
					SUM(b.comm *b.actualrate) commIncomeLicenseeMYR,
					SUM( playercomm  ) PlayercommIncomeLicensee,
					SUM( playercomm *b.actualrate) PlayercommIncomeLicenseeMYR,
					--PT Winloss Licensee 
					SUM(b.awinlost + b.mwinlost + b.swinlost) PTWLLicensee,
					SUM((b.awinlost + b.mwinlost + b.swinlost)*b.actualrate) PTWLLicenseeMYR	
			FROM	bettrans14 b WITH (NOLOCK) 
					INNER JOIN Outright14 o WITH (NOLOCK) ON b.matchid = o.orid 
					INNER JOIN @TempAg ag ON b.recommend = ag.custId AND b.currency = ag.currency
			WHERE	b.winlostdate = @wldate 
					AND b.bettype in (31,32,33)
					AND b.statusID NOT IN (101,102,103,121)
					 
			GROUP BY o.leagueid, o.groupmatch, b.currency
	)hr
	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@wldate,@wldate))e 
	ON  hr.currency = e.exchangeid
	ORDER BY currencyName, leagueid, CAST (groupmatch AS TINYINT)
END
	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlostRacing] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlostRacing] TO [vnteam] AS [dbo]
