USE [bodb_licensee]
 
GO
ALTER PROCEDURE [dbo].[Lrf_rpt_DWWinloss]
	@LicenseeID		INT,
    @FromDate		SMALLDATETIME,
    @ToDate			SMALLDATETIME,
    @groupingid		INT = 1,  
    @drawfilter		INT = 1,
	@basedcurrency	SMALLINT = 0,
	@AgentList		VARCHAR(MAX)
 AS 
 /*
Created: 20140331@Winnie
Task : 
DB: DBLIC.bodb_licensee
Original:

Revisions:	
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150127@Jim: support base on GBP Currency
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, Add param @LicenseeID [Redmine: #71679]
Param's Explanation:
    @groupingid: used to group data for summarizing (1:by day, 2:month, 3:currency, 4:bettype, 5:league)    
    @drawfilter: 'No Draw' filter is supported (1:Normal 2:No Draw 3:No Draw for Turnover only)
*/
BEGIN
	DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #currency(Currency INT, CurrencyName VARCHAR(20))

	INSERT INTO #currency(Currency, CurrencyName)
	SELECT DISTINCT b.Currency, lc.CurrencyName
	FROM @TempAg b
		INNER JOIN dbo.f_SelLicenseeCust(@LicenseeID) lc ON b.Currency = lc.Currency AND b.CustId = lc.CustID
	WHERE b.Currency <> 20

	DECLARE @Exchange	AS TABLE (
		ExchangeDate	SMALLDATETIME,
		ExchangeId		INT,
		Code			VARCHAR(20) NULL,
		MYR				FLOAT,
		USD				FLOAT,
		EUR				FLOAT,
		GBP				FLOAT
		, PRIMARY KEY(ExchangeDate,ExchangeId)
	)
	INSERT INTO @Exchange (ExchangeDate,ExchangeId,Code,MYR,USD,EUR,GBP)
	SELECT	ExchangeDate,
			ExchangeId,
			c.CurrencyName,
			MYR,
			USD,
			EUR,
			GBP
	FROM bodb02.dbo.Lrf_f_GetExchangeDaily(@FromDate,@ToDate) a
		INNER JOIN #currency c ON a.ExchangeId = c.Currency

	CREATE TABLE #TempData
	(
	
		Date				SMALLDATETIME ,
		Month				VARCHAR(7),
		Currency			VARCHAR(3),
		BetType				NVARCHAR(50),
		League				VARCHAR(100),
		TurnOver			MONEY ,	
		MemberWinLost		MONEY ,		
		Betcount			INT		
	)

		INSERT INTO #TempData
			SELECT  			
				b.rptDate AS Date ,
				convert(varchar(7),b.rptDate,120) AS Month,
				e.Code AS Currency,
				b.Bettype AS Bettype,
				b.LeagueID AS League,
				CASE @basedcurrency
				WHEN -2
				THEN
				SUM(case when (@DrawFilter in (2,3) and b.Status=111) then 0
						when (@DrawFilter in (2,3) and b.Status IN (114,115)) then 0.5*Turnover*e.USD	
						 else Turnover*e.USD
					end
				)
				WHEN -1
				THEN
				SUM(case when (@DrawFilter in (2,3) and b.Status=111) then 0
						when (@DrawFilter in (2,3) and b.Status IN (114,115)) then 0.5*Turnover*e.EUR					
						 else Turnover*e.EUR
					end
				)
				WHEN -3
				THEN
				SUM(case when (@DrawFilter in (2,3) and b.Status=111) then 0
						when (@DrawFilter in (2,3) and b.Status IN (114,115)) then 0.5*Turnover*e.GBP					
						 else Turnover*e.GBP
					end
				)
				ELSE
					SUM(case when (@DrawFilter in (2,3) and b.Status=111 ) then 0
						when (@DrawFilter in (2,3) and b.Status IN (114,115)) then 0.5*Turnover
						 else b.Turnover
					end
				)
				END AS TurnOver,
				CASE @basedcurrency
				WHEN -2
				THEN
				SUM((b.WinLoss)*e.USD)
				WHEN -1
				THEN
				SUM((b.WinLoss )*e.EUR)
				WHEN -3
				THEN
				SUM((b.WinLoss )*e.GBP)
				ELSE
					SUM(b.WinLoss)
				END AS MemberWinLost,
			
				----
	
				SUM(case when (@DrawFilter =2 and b.Status=111) then 0					 
					else b.BetCount
					end) as betcount
			FROM    
				bodb_licenseereport.dbo.rpt_Betting b WITH ( NOLOCK)
				INNER JOIN #currency c ON b.CurrencyID = c.Currency
				LEFT JOIN @Exchange e  ON e.ExchangeDate = b.rptDate AND e.exchangeid = b.CurrencyID
			WHERE   
				b.rptDate BETWEEN @FromDate AND @ToDate
				AND Status <>103		
				AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
								  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
					)	
				AND b.SiteID = @LicenseeID			
			GROUP BY b.rptDate,	e.Code,b.Bettype,b.LeagueID

		
	IF(	@groupingid=1)
	BEGIN
	SELECT 
			w.Date,	
			SUM(TurnOver)			AS TurnOver ,    
			SUM(MemberWinLost)		AS MemberWinLost ,   
			-SUM(MemberWinLost)		AS LicenseeWL,
			SUM(w.betcount) BetCount
		
	FROM		
			#TempData w	
		
	GROUP BY w.Date

	END
	ELSE IF(@groupingid=2)
	BEGIN
	SELECT 
			w.Month,	
			SUM(TurnOver)			AS TurnOver ,    
			SUM(MemberWinLost)		AS MemberWinLost ,   
			-SUM(MemberWinLost)		AS LicenseeWL,
			SUM(w.betcount) BetCount      
		
	FROM		
			#TempData w			
	GROUP BY w.Month

	END  
	ELSE IF(@groupingid=3)
	BEGIN
	SELECT 
			w.Currency,	
			SUM(TurnOver)			AS TurnOver ,    
			SUM(MemberWinLost)		AS MemberWinLost ,     
			-SUM(MemberWinLost)		AS LicenseeWL,
			SUM(w.betcount) BetCount
	FROM		
			#TempData w			
	GROUP BY w.Currency


	END    
	ELSE IF(@groupingid=4)
	BEGIN
	SELECT 
			W.BetType,	
			SUM(TurnOver)			AS TurnOver ,    
			SUM(MemberWinLost)		AS MemberWinLost ,    
			-SUM(MemberWinLost)		AS LicenseeWL,
			SUM(w.betcount) BetCount
	FROM		
			#TempData w			
	
	GROUP BY W.BetType	

	END      
	ELSE IF(@groupingid=5)
	BEGIN
	SELECT 
			w.League,	
			SUM(TurnOver)			AS TurnOver ,    
			SUM(MemberWinLost)		AS MemberWinLost ,    
			-SUM(MemberWinLost)		AS LicenseeWL,
			SUM(w.betcount) BetCount
	FROM		
			#TempData w			
			GROUP BY
			w.League		
	END  
	DROP TABLE #TempData

END
GO
GRANT EXECUTE ON [Lrf_rpt_DWWinloss] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_rpt_DWWinloss] TO [vnteam]
GO