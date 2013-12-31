USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_CustomerTurnOver]    Script Date: 27/12/2013 2:20:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver]
	 @LicenseeID INT,
	 @UserID  INT,
	 @Username VARCHAR(50)='', 
	 @Product  VARCHAR(MAX), 
	 @Bettype  VARCHAR(MAX), 
	 @CurrencyID INT,
	 @FromDate SMALLDATETIME,
	 @ToDate SMALLDATETIME,
	 @Odds FLOAT,
	 @ReportBy  TINYINT   = 1, 
	 @MoveBetsDay SMALLDATETIME,
	 @BalanceUpDay SMALLDATETIME,
	 @Langkey NVARCHAR(10)='en-US' ,
	 @PageSize INT=1000,
	 @PageIndex INT=1,
	 @IsExportExcel bit =0,
	 @ShowWin bit=1,
	 @ShowLoss bit=1,
	 @ShowDraw bit=1
AS

/*	
	Created	: Henry
	Task: Customer Performance Report
	Date: 2011-12-28
	DB: DBEXT/BODB02
	Original: Lrf_Rpt_CustomerPerformance
	Revision:
	- 20120214@Henry: Seperate 3 options: Win/Loss/Draw (and all)
	- 20120801@Jim: add PlayerComm value 
    - 20130124@Daniel: Change link server alias
	- 20130618@Jim:  Restrict permission of Licensee Users by currency
	- 20131021@Jim: Add more products to Customer Turnover Report
	- 20131130@Florent: turning SP
	- 20131205@Florent: add more product and search LIKE customer
	- 20131225@Florent: Remove using bettrans14, use only bettrans and rptCustomerturnover
	Parameter's Explanation:
		- @ReportBy:  1: daily, 2: monthly
		- @FilterBy:  1: Win, 2: Loss, 3: Draw
		- @SportID   : Sport type ID  
		- @bettype   : Bet type ID  
		- @MoveBetsDay: The day we move tickets to bettrans14
		- @BalanceUpDay: The day we move tickets to bettrans_bk
		
			
*/
SET NOCOUNT ON

DECLARE @TempFromDate SMALLDATETIME
DECLARE @TempToDate SMALLDATETIME
DECLARE @CustID INT
/* in case Licensee is Sungame, user cannot search in all of currency.
 Other case, when input search by username , this mean search in all of currency
*/
/*
IF (@LicenseeID<>8) -- SunGame
BEGIN 
	SET @CurrencyID=0
END
*/
CREATE TABLE #Data
(
	CustID INT,
	winlostdate DATETIME,
	sporttype INT, 
	bettype INT,
	currency SMALLINT,
	Turnover	MONEY,   
	Winlost		MONEY,
	PlayerComm  MONEY,
	Odds SMALLMONEY,
	OddsType SMALLINT,
	betcount SMALLINT
)

DECLARE @Status AS TABLE
(
	StatusID INT
)

DECLARE @RowStart INT ,
          @RowEnd INT ,
		  @TotalRow INT		
SELECT VAL sportID INTO #ProductID FROM strSplit(@Product,',')
SELECT VAL bettypeID INTO #BettypeID FROM strSplit(@Bettype,',')
CREATE TABLE #CustID (Custid INT)
SELECT 
		b.typeID,
		CASE @Langkey
					WHEN 'zh-CN'	THEN typenamcn
					WHEN 'zh-TW'	THEN typenamecn
					WHEN 'th-TH'	THEN typenameth
					WHEN 'ja-JP'	THEN typenamej
					WHEN 'ko-KR'	THEN typenameko
					WHEN 'es'  	    THEN typenameES
					WHEN 'vi-VN'	THEN typenamee
					ELSE typenamee END typenamee
INTO #bettype		
FROM 
		dbo.bettype  b WITH (NOLOCK)
		INNER JOIN #BettypeID bt ON b.typeid=bt.bettypeID

UPDATE #bettype SET #bettype.typenamee=bettype.typenamee 
FROM #bettype INNER JOIN bettype ON #bettype.typeid=bettype.typeid 
WHERE #bettype.typenamee IS NULL 

SELECT  @PageIndex = @PageIndex - 1 ,
            @RowStart = @PageSize * @PageIndex + 1 ,
            @RowEnd = @RowStart + @PageSize - 1 
IF  NOT EXISTS (SELECT TOP 1 1  FROM #ProductID )
	BEGIN 
		RETURN
	END 
ELSE 
	BEGIN 
		;with cte_recommend
			as
			(
			SELECT LicenseeID
				  ,CustID
				  ,Currency
			FROM DBLIC.bodb_licensee.dbo.LicenseeCust  WITH (NOLOCK)
			WHERE
				LicenseeID=@LicenseeID
				AND (Currency=@CurrencyID)-- OR (@CurrencyID=0))
				AND RoleID=2
			)
			
			
		SELECT  re.CustID
		INTO #recommend
		FROM cte_recommend re
			INNER JOIN DBLIC.bodb_licensee.dbo.CurrencyUser c WITH (NOLOCK) ON re.LicenseeID=c.LicenseeID AND re.Currency=c.CurrencyID
		WHERE 
			c.usrID=@userID 
			AND c.SystemID=1 -- System is default=1 (LRF)	
			AND c.isActive=1
			
			
		SELECT lc.CustID INTO #Currency
		FROM DBLIC.bodb_licensee.dbo.LicenseeCustInfo lc WITH (NOLOCK) 
		WHERE
			recommend IN (SELECT CustID FROM #recommend)
		--DROP TABLE 	#recommend
		
		SELECT @Username = ltrim(rtrim(@Username))
		IF ISNULL(@Username,'')<>''
			BEGIN 
				INSERT INTO #CustID
				SELECT cr.custid
				FROM Customer cr (NOLOCK)
					INNER JOIN #Currency c ON cr.CustID=c.CustID
				WHERE username2 LIKE '%$%' + @Username+'%'
				

				INSERT INTO #CustID
					SELECT cr.CustID 
					FROM Customer cr(NOLOCK)
						INNER JOIN #Currency c ON cr.CustID=c.CustID
					WHERE username  like '%'+@Username+'%'
			END
		ELSE 
			IF ISNULL(@Username,'')=''
				BEGIN 
					SELECT @CustID=0
				END		
		IF @ShowWin =1
		BEGIN
			INSERT INTO @Status
			SELECT 112
			INSERT INTO @Status
			SELECT 114
			
		END 
		IF @ShowLoss=1
		BEGIN
			INSERT INTO @Status
			SELECT 113
			INSERT INTO @Status
			SELECT 115
		END

		IF  @ShowDraw=1
		BEGIN
			INSERT INTO @Status
			SELECT 111
		END

		IF @Todate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay 
				SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate
			;WITH cte_raceinfo
				AS 
				(
					SELECT  o.Orid,r.SportType,r.LeagueID,o.EventDate
					FROM dbo.VSOutright  o WITH (NOLOCK)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID  
					WHERE EventTime BETWEEN @TempFromDate AND @ToDate
				)
			INSERT INTO #Data
			SELECT 
				b.CustID,
				winlostdate,
				CASE 
					WHEN b.bettype NOT IN (9,10,29,1231,1232,1233,1237,1238) THEN m.sporttype
					WHEN b.bettype IN (1231,1232,1233,1237,1238) THEN cr.SportType
					ELSE 1 END sporttype,
				b.bettype,
				currency,
				stake as turnover,
				b.winlost - b.actual_stake as winlost,
				b.PlayerComm ,
				b.Odds,
				b.Oddstype,
				1 betcount
			FROM bettrans b WITH (NOLOCK)
			INNER JOIN #bettype bet  ON b.bettype=bet.typeID
			LEFT JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN outright o with(nolock) ON b.matchid = o.orid 
			LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
			LEFT JOIN cte_raceinfo AS cr ON cr.orid=b.oddsid 
			WHERE 
				b.CustID IN (SELECT CustID FROM #Currency) AND 
				 b.winlostdate BETWEEN @TempFromDate AND @todate
				--AND (b.CustID = @CustID OR @CustID=0)
				AND (b.custid IN (SELECT * FROM #custID) OR @CustID=0)
				AND b.statusID IN (SELECT StatusID FROM @Status)
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @ToDate
			;WITH cte_raceinfo
				AS 
				(
					SELECT  o.Orid,r.SportType,r.LeagueID,o.EventDate
					FROM bodb_archive.dbo.VSOutright_bk o WITH (NOLOCK)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID  
					WHERE EventTime BETWEEN @fromDate AND @TempToDate
					UNION ALL
					SELECT  o.Orid,r.SportType,r.LeagueID,o.EventDate
					FROM dbo.VSOutright14 o WITH (NOLOCK)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID  
					WHERE EventTime BETWEEN @fromDate AND @TempToDate					
				)
			,cte_temp_bk
			AS (
				SELECT bk.winlostdate
					,bk.CustID
					--,bk.sporttype sporttype
					,CASE WHEN bk.bettype IN (1220,1235,1236) THEN 186 
						  WHEN bk.bettype IN (9,10,29) THEN 1
						ELSE bk.sporttype 
						END sporttype  
					,bk.bettype
					,bk.currency
					,bk.stake AS turnover
					,bk.winlost 
					,bk.PlayerComm
					,bk.Odds
					,bk.oddstype
					,bk.statusID
					,bk.betcount
				FROM bodb_LicenseeReport.dbo.rptcustomerturnOver bk WITH (NOLOCK)
				INNER JOIN #recommend re ON bk.recommend=re.custid
				INNER JOIN #bettype	bt ON bk.bettype=bt.typeid 
				WHERE bk.winlostdate BETWEEN @fromdate AND @TempToDate
					/*AND bk.bettype IN (
						SELECT b.typeid
						FROM #bettype b
					)*/					
					AND (						
						EXISTS (SELECT 1 FROM #Custid WHERE bk.custid=#CustID.Custid)
						OR @CustID = 0
					)
									
					--AND bodb_LicenseeReport.$PARTITION.pf_rptcustomerturnOver_monthly(winlostdate) in (@i,@i+1)
					AND bk.STATUSID IN (
						SELECT statusid
						FROM @Status
						)
				)
			INSERT INTO #Data
			SELECT b.CustID
				,b.winlostdate
				,b.sporttype
				,b.bettype
				,currency
				,b.turnover
				,b.winlost
				,b.PlayerComm
				,b.Odds
				,b.Oddstype
				,b.betcount
			FROM cte_temp_bk b	
		END
		
		END
		*/
		
		
		UPDATE #Data
		SET odds = CASE WHEN OddsType = 1 THEN odds + 1 --decimal
						WHEN OddsType = 2 THEN Odds + 1 --hongkong to decimal
						WHEN OddsType IN (3,4) THEN --malay and indo to decimal
												CASE 
													WHEN odds < 0 THEN (1 -  cast(1 as float) / cast(odds AS float))
													WHEN odds >=0 THEN (1 + odds) END
						WHEN OddsType = 5 THEN --american odds to decimal
											CASE
											WHEN (odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (odds AS float))
											WHEN (odds * 100) % 2 = 0 THEN 2
											WHEN (odds * 100) > 0 THEN (1 + odds) END 
						ELSE odds END		
		WHERE 
			bettype IN (1,2,3,7,12,8,20)	
			OR bettype BETWEEN 81 AND 88
			OR bettype BETWEEN 90 AND 120

		SELECT 
			CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
				WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
				ELSE '0' END ReportBy, 
				A.RowNum,		
				A.username,
				A.sporttype,
				A.Currency,
				A.bettype,
				A.Betcount,
				A.Turnover,
				A.Winlost,
				A.PlayerComm
				INTO #result 
		FROM 
		(	
		SELECT   
			ROW_NUMBER() over(order by username,sporttype,bettype ASC) AS RowNum,
			b.winlostdate,
			ISNULL(substring(c.username2,charindex ('$',c.username2,1)+1,len(c.username2)),c.username) as username,
			CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN e.currency
				ELSE e.Code END AS Currency,
			b.sporttype,		
			CASE WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND bt.typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238)) THEN  N'V.Soccer - '+bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND bt.typeid IN (1231,1232,1233)) THEN  N'V.Racing - '+bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND bt.typeid IN (1220,1235,1236)) THEN  N'V.Tennis - '+bt.typenamee
				 ELSE  bt.typenamee
			END AS bettype,
			sum(b.betcount) AS Betcount,
			sum(b.turnover) AS Turnover,
			sum(b.winlost) AS Winlost,
			SUM(PlayerComm) AS PlayerComm
			
		FROM #Data b
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustID=c.CustID 
			INNER JOIN #bettype bt WITH (NOLOCK) ON b.bettype = bt.typeid
			INNER JOIN exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
		WHERE 
			(b.Sporttype IN (SELECT sportID FROM #ProductID)OR b.sporttype =0)
			AND b.Odds >= @Odds
			AND c.RoleID=1

			 
		GROUP BY 
			b.winlostdate,	
			ISNULL(substring(c.username2,charindex ('$',c.username2,1)+1,len(c.username2)),c.username),
			CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN e.currency
				ELSE e.Code END,
			c.username,	
			b.sporttype,	
			b.bettype,
			CASE WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND bt.typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238)) THEN  N'V.Soccer - '+bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND bt.typeid IN (1231,1232,1233)) THEN  N'V.Racing - '+bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND bt.typeid IN (1220,1235,1236)) THEN  N'V.Tennis - '+bt.typenamee
				 ELSE  bt.typenamee
			END
			)A
		
		ORDER BY
			CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
				WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
				ELSE '0' END
	--- Data Detail 
		SELECT *
		INTO #return
		FROM
		(
		SELECT  
			ROW_NUMBER() over(order by ReportBy,username,sporttype,bettype ASC) AS RowNo,
			ReportBy,  
			username,
			Currency,
			sporttype,
			bettype,
			SUM(Betcount) Betcount ,
			SUM(Turnover) Turnover,
			SUM(Winlost) Winlost,
			SUM(PlayerComm) PlayerComm
		FROM #result 	
		GROUP BY 
			ReportBy,  
			username,
			Currency,
			sporttype,
			bettype
		) B
		SELECT * FROM #return	
		WHERE ( RowNo between @RowStart AND @RowEnd	AND  @IsExportExcel=0) OR (@IsExportExcel=1 AND RowNo<65000)
	--- Data Sum 	
		SELECT @TotalRow=COUNT(1)
		FROM #return
				
		SELECT sum(betcount) Sumbetcount,
			   sum(Turnover) SumTurnover,
			   sum(Winlost) SumWinlost ,
			   sum(PlayerComm) SumComm,
			   @TotalRow  TotalRows
		FROM #result  	
		WHERE (@IsExportExcel=0) OR (@IsExportExcel=1 AND RowNum<65000)
				DROP TABLE #return	
		DROP TABLE #Data	
		DROP TABLE #result	
		DROP TABLE #Currency 
		DROP TABLE #bettype
		DROP TABLE #custID
		DROP TABLE 	#recommend
	END
DROP TABLE #ProductID
DROP TABLE #BettypeID

GO
ALTER AUTHORIZATION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO  SCHEMA OWNER 
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] AS [dbo]
GO