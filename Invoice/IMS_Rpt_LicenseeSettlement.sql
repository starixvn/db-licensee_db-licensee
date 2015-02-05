USE [bodb02]
GO

ALTER PROCEDURE [dbo].[IMS_Rpt_LicenseeSettlement]
	@licenseeId INT,
	@licenseeName VARCHAR(50),
	@fromDate SMALLDATETIME,
	@toDate SMALLDATETIME,
	@product INT = 0,
	@currency INT = 0
AS
	/*  Created: Kevin
		Date: 20130418
		Task : Report - Licensee Settlement Report
		DB: DB052.bodb02
		Revisions:  
			2013-Aug-23@Victor: Support NG and LC product
			2013-Sep-05@Victor: Support VS product
			2014-May-05@Victor: Exclude PlayerComm on Winloss column for BA product
			20150202@Patrick: Add more GBP currency & Sporting Solution

		Param's Explanation:  	
			+ @licenseeId:
			+ @fromDate:
			+ @toDate:
			+ @product: 0 -> Sportsbook			1 -> Racing
						2 -> Number Game		3 -> BA
						4 -> Live Casino		5 -> Virtual Sports
						6 -> RNG Casino			7 -> Bingo
			+ @currency:
	*/  
	SET NOCOUNT ON
	
	DECLARE  @isGetOldData BIT
	IF 	@fromDate < '2009-12-31'
		SET @isGetOldData = 1;
	ELSE 
		SET @isGetOldData = 0;
	
	DECLARE @tempAg	TABLE( custID INT,currency INT) 	
	DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
	DECLARE @sporttype TABLE(sporttype INT)		
	DECLARE @moveBetsDay SMALLDATETIME
	SELECT @moveBetsDay = MAX(m.eventdate) FROM dbo.match14 m WITH(NOLOCK)  			 

	CREATE TABLE #SAgWinLoss  (  	
		winlostdate		DATETIME,
		Currency		INT,
		TurnOver		MONEY,
		Winlost			MONEY,
		PlayerComm 		MONEY,
		LicenseeWL		MONEY,
		LicenseeComm 	MONEY,
		Company			MONEY,
		Betcount		BIGINT
	)
	
	INSERT INTO @tempAg (custID, currency) 
		SELECT custID, currency FROM bodb_Licensee.dbo.LicenseeCust (NOLOCK) 
		WHERE 																
			LicenseeID = @licenseeId										
			AND (@Currency = 0 OR (@Currency<> 0 AND Currency=@Currency))	
			AND (Currency <> 20)

	DECLARE @Super AS TABLE (custid int primary key, currency int)				   
	INSERT INTO @Super(custid, currency)  
	SELECT CustID, currency FROM Dep_CustSuper WITH (NOLOCK)  
	WHERE  site = @licenseeName			  	

	IF @product = 0  --Sportsbook										 
	BEGIN  	   
		INSERT  INTO @sporttype( sporttype)
		VALUES  (0)						   
	END 
	 
	IF @product = 2  --Number Game										 
	BEGIN  	   
		INSERT INTO @sporttype(Sporttype)  
		VALUES(161) 	
		INSERT INTO @bettype(bettype)
		SELECT typeid FROM bettype (NOLOCK)
		WHERE (typeid BETWEEN 81 AND 120)						   
	END  

	IF @product = 4 -- Live Casino
	BEGIN  	   
		INSERT INTO @sporttype(Sporttype)  
		VALUES(162) 	
		INSERT INTO @bettype(bettype)
		SELECT typeid FROM bettype (NOLOCK)
		WHERE (typeid BETWEEN 1101 AND 1199)						   
	END

	IF @product = 5 -- Virtual Sports
	BEGIN  	   
		INSERT INTO @sporttype(Sporttype)  
		SELECT SportType FROM Sports (NOLOCK)
		WHERE (SportType BETWEEN 180 AND 186)

		INSERT INTO @bettype(bettype)
		SELECT typeid FROM bettype (NOLOCK)
		WHERE (typeid BETWEEN 1201 AND 1299)						   
	END


	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME 	   
	DECLARE @MaxOldDate DATETIME	   
	DECLARE @FDate DATETIME 		   
	DECLARE @TDate DATETIME 		   
	--to Deal With Parameter Sniffing 

	SELECT @FDate=@fromDate, @TDate=@toDate 	
	IF @TDate > @moveBetsDay  
	BEGIN				
		IF @FDate <= @moveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@moveBetsDay)	 
		ELSE												 
			SET @TempFromDate = @FDate

		IF @product = 0  -- Sporstbook			
		BEGIN		
			INSERT INTO #SAgWinLoss
			SELECT   			   
				b.winlostdate,     
				s.currency,		   
				SUM(stake) AS turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,
				SUM(PlayerComm) AS PlayerComm,
				SUM(b.awinlost) AS LicenseeWL,				
				SUM(b.comm - playercomm) AS LicenseeComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AS Company, 
				COUNT(b.transid) AS BetCount	  
			FROM 			
				Bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
				INNER JOIN @Super s ON b.srecommend = s.custid	  
				INNER JOIN @TempAg a ON b.recommend = a.custid	
			WHERE 											  
				b.winlostdate BETWEEN @TempFromDate AND @TDate AND 	
				b.statusID  IN (111, 112, 113) AND				   
				(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) AND 
				b.tpositiontaking <> 0	 
			GROUP BY   						  
				b.winlostdate, s.currency 
		END	
		
		IF @product = 3 -- BA
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT   
				b.winlostdate,  
				b.currency,
				SUM(stake) AS turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				0 AS PlayerComm,
				SUM(comm) AS LicenseeWL, -- BA Comm
				0 AS LicenseeComm,
				- SUM(b.winlost - b.actual_stake + awinlost + comm) AS Company, --Amount Due to BA
				COUNT(b.transid) AS BetCount
			FROM 
				dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)    
				INNER JOIN @Super s ON b.srecommend = s.custid
				INNER JOIN @TempAg tma ON tma.CustID = b.recommend			
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON s.custid = BA.srecommend and b.transid = BA.transid 	 
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
				b.statusID  IN (111, 112, 113) 
			GROUP BY   
				b.winlostdate, b.currency
		END	
		
		IF @product = 2  -- Number Game
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				s.currency,
				SUM(stake) turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				SUM(PlayerComm) AS PlayerComm,
				SUM(awinlost) AS LicenseeWL,		
				SUM(b.comm - playercomm) AS LicenseeComm,		
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company,
				COUNT(b.transid) AS BetCount	
			FROM 
				Bettrans b WITH ( NOLOCK,INDEX=IX_srecommend )
				INNER JOIN @Super s ON b.srecommend = s.custid
				INNER JOIN @TempAg a ON b.recommend = a.custid
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
				b.statusID  IN (111, 112, 113) 
			GROUP BY   
				b.winlostdate, s.currency
		END  	
		
		IF @product = 4  -- Live Casino
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				s.currency,
				SUM(stake) turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				SUM(PlayerComm) AS PlayerComm,
				SUM(awinlost) AS LicenseeWL,		
				SUM(b.comm - playercomm) AS LicenseeComm,		
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company,
				COUNT(b.transid) AS BetCount	
			FROM 
				Bettrans b WITH ( NOLOCK,INDEX=IX_srecommend )
				INNER JOIN @Super s ON b.srecommend = s.custid
				INNER JOIN @TempAg a ON b.recommend = a.custid
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
				b.statusID  IN (111, 112, 113) 
			GROUP BY   
				b.winlostdate, s.currency
		END	

		IF @product = 5  -- Virtual Sports
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				s.currency,
				SUM(stake) turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				SUM(PlayerComm) AS PlayerComm,
				SUM(awinlost) AS LicenseeWL,		
				SUM(b.comm - playercomm) AS LicenseeComm,		
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company,
				COUNT(b.transid) AS BetCount	
			FROM 
				Bettrans b WITH ( NOLOCK,INDEX=IX_srecommend )
				INNER JOIN @Super s ON b.srecommend = s.custid
				INNER JOIN @TempAg a ON b.recommend = a.custid
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
				b.statusID  IN (111, 112, 113) 
			GROUP BY   
				b.winlostdate, s.currency
		END

	END  	
    
	IF @FDate <= @moveBetsDay  
	BEGIN 
		IF @TDate >= @moveBetsDay	  
			SET @TempToDate = @moveBetsDay	
		ELSE							   
			SET  @TempToDate = @TDate	
			  
		--	Sportsbook	& Number Game & Live Casino & Virtual Sports
		IF @product IN (0,2,4,5) 
		BEGIN				
			INSERT INTO #SAgWinLoss   
			SELECT 					
				b.winlostdate,  	
				b.currency, 		 
				SUM(b.turnover) AS turnover,     		   
				SUM(b.winlost) AS Winlost,    
				SUM(b.playercomm ) AS PlayerComm,
				SUM(b.awinlost) AS LicenseeWL,				
				SUM(b.comm - b.playercomm) AS LicenseeComm,
				- SUM(b.awinlost + b.winlost + b.comm) AS Company,	  
				SUM(b.betcount)	 AS BetCount
			FROM 				
				bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )    
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype 
				INNER JOIN @TempAg ag ON ag.custid = b.recommend	 
			WHERE  								  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  	 
				AND b.roleid = 2   							  
				AND b.statusID <> 101 --exclude REJECT bets	   
				AND ISNULL(b.isBA,0) = 0 --exclude BA tickets					 
			GROUP BY  b.winlostdate, b.currency
		END	
		
		IF @product = 3 -- BA
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.turnover) AS turnover,     					
				SUM(b.winlost) AS Winlost,  
				0 AS PlayerComm,
				SUM (comm) AS LicenseeWL, -- BA Comm		
				0 AS LicenseeComm,				
				- SUM (b.winlost + b.awinlost + b.comm) AS Company, -- Amount Due to BA
				SUM(b.betcount) AS BetCount
			FROM 
				bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON ag.custid = b.recommend
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 2   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA,0) = 1
			GROUP BY  b.winlostdate, b.currency
		END	 
	END 

	IF @isGetOldData = 1 
	BEGIN
		SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_Licensee.dbo.rptLicWinloss_old (NOLOCK)
		IF @TDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @TDate
	
		--	Sportsbook	& Number Game & Live Casino
		IF @product IN (0,2,4,5)
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.turnover),     
				SUM(b.winlost),  																							
				SUM ( playercomm) as PlayerComm,
				SUM(b.awinlost) AS LicenseeWL,
				SUM(b.comm - b.playercomm) as LicenseeComm,
				- SUM(b.awinlost + b.winlost + b.comm) AS Company,
				SUM(b.betcount) AS BetCount		
			FROM 
				bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON ag.custid = b.recommend
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 2   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA,0) = 0 --exclude BA tickets
			GROUP BY  b.winlostdate, b.currency
		END
	
	END

	CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)	   
	SELECT * INTO #TempExchange 									   
	FROM IMS_f_ExchangeDailySel(@FDate,@TDate)						   
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)	   
	SELECT   														   
	   (
		   CASE WHEN GETDATE() < (DATEADD(s,-1, DATEADD(mm, DATEDIFF(m,0,w.winlostdate)+1,0))) 
		   THEN GETDATE() 
		   ELSE (DATEADD(s,-1, DATEADD(mm, DATEDIFF(m,0,w.winlostdate)+1,0))) END													   
	   )  AS WinLostMonth,  										 
	   Currency,   														 
	   e.Code CurrencyName,								 
	   SUM(TurnOver)	AS Turnover,   
	   SUM(Betcount)	AS Betcount, 										 
	   SUM(Winlost)		AS MemberWinLoss,  										 
	   SUM(PlayerComm)	AS MemberComm,
	   SUM(LicenseeWL)	AS LicenseeWL,		   
	   SUM(LicenseeComm)AS LicenseeComm,	
	   SUM(Company)		AS Company,	
	   --Base currency
	   e.EUR,
	   e.USD,
	   e.CNY,
	   e.MYR,
	   e.GBP
	FROM													  
		#SAgWinLoss w   									  
		INNER JOIN  #TempExchange e							  
		ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
	GROUP BY   														   
		Currency													   
		,(
		   CASE WHEN GETDATE() < (DATEADD(s,-1, DATEADD(mm, DATEDIFF(m,0,w.winlostdate)+1,0))) 
		   THEN GETDATE() 
		   ELSE (DATEADD(s,-1, DATEADD(mm, DATEDIFF(m,0,w.winlostdate)+1,0))) END													   
	   ),
		e.Code,
		e.EUR,
		e.USD,
		e.CNY,
		e.MYR,
	    e.GBP						   
	ORDER BY WinLostMonth  													   

	DROP TABLE #TempExchange												   
	DROP TABLE #SAgWinLoss

GO

GRANT EXECUTE ON [dbo].[IMS_Rpt_LicenseeSettlement] TO [bodbAdminNet] AS [dbo]
GO


