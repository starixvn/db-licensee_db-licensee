USE [bodb02]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver]
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
	- 20140104@Don: Improve performance -> Replacing table @Status with #Status
	- 20140120@Florent: using index Non clusered IX_recommend for table rptCustomerturnover
	- 20140212@Florent : Sorting DESC
	- 20140716@Jim: fix bug Total row in excel file is incorrect (hotfix #19101)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20141203@Jim : fix issue cannot query data when pass a User belong to CNY Currency (hot fix #27017)
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

CREATE TABLE #Data
(
	CustID INT,
	winlostdate DATETIME,
	sporttype INT, 
	bettype INT,
	currency SMALLINT,
	Turnover	MONEY,
	oddsid		INT,
	Winlost		MONEY,
	PlayerComm  MONEY,
	Odds SMALLMONEY,
	OddsType SMALLINT,
	betcount SMALLINT
)
--CREATE INDEX IDX_CustID ON #Data(CustID)
CREATE TABLE #Status(StatusID INT)

DECLARE @RowStart INT ,
        @RowEnd INT ,
		@TotalRow INT		

SELECT VAL sportID INTO #ProductID FROM strSplit(@Product,',')
INSERT INTO #ProductID (sportId) SELECT 0

SELECT VAL bettypeID INTO #BettypeID FROM strSplit(@Bettype,',')

CREATE TABLE #CustID (Custid INT)
SELECT 
	b.typeID,
	CASE @Langkey
				WHEN 'zh-CN'	THEN typenamecn
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

UPDATE #bettype
SET #bettype.typenamee=bettype.typenamee 
FROM #bettype 
INNER JOIN bettype ON #bettype.typeid=bettype.typeid 
WHERE #bettype.typenamee IS NULL 

SELECT  @PageIndex = @PageIndex - 1 ,
		@RowStart = @PageSize * @PageIndex + 1 ,
		@RowEnd = @RowStart + @PageSize - 1 

 
SELECT  lc.CustID
		,lc.Currency
INTO #recommend
FROM bodb_licensee.dbo.f_SelLicenseeCust (@LicenseeID) lc  
	INNER JOIN  bodb_licensee.dbo.CurrencyUser c WITH (NOLOCK) ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE
	(lc.Currency=@CurrencyID OR @CurrencyID IN (13,66))-- OR (@CurrencyID=0))		
	AND lc.RoleID=2
	AND c.usrID=@userID 
	AND c.SystemID=1 -- System is default=1 (LRF)	
	AND c.isActive=1
		
		
IF  NOT EXISTS (SELECT TOP 1 1  FROM #ProductID )
	BEGIN 
		RETURN
	END 
ELSE 
	BEGIN 
	
		SELECT @Username = ltrim(rtrim(@Username))
		IF ISNULL(@Username,'')<>''
			BEGIN 
				
				INSERT INTO #CustID
				SELECT cr.custid
				FROM Customer cr (NOLOCK)
					INNER JOIN #recommend re ON cr.Recommend=re.CustID AND cr.Currency = re.Currency
				WHERE username2 LIKE '%$%' + @Username+'%'
					
				
				INSERT INTO #CustID
					SELECT cr.CustID 
					FROM Customer cr(NOLOCK)
						INNER JOIN #recommend re ON cr.Recommend=re.CustID AND cr.Currency = re.Currency
					WHERE username  like '%'+@Username+'%'
			END
			ELSE 
			IF ISNULL(@Username,'')=''
				BEGIN 
					SELECT @CustID=0
				END		
		IF @ShowWin =1
			BEGIN
				INSERT INTO #Status
				SELECT 112
				INSERT INTO #Status
				SELECT 114
				
			END 
		IF @ShowLoss=1
			BEGIN
				INSERT INTO #Status
				SELECT 113
				INSERT INTO #Status
				SELECT 115
			END

		IF  @ShowDraw=1
			BEGIN
				INSERT INTO #Status
				SELECT 111
			END


		IF @Todate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay 
				SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate
			
			INSERT INTO #Data
			SELECT 
				b.CustID,
				winlostdate,
				CASE 
					WHEN b.bettype NOT IN (9,10,29) THEN m.sporttype
					ELSE 1 END sporttype,
				b.bettype,
				b.currency,
				stake as turnover,
				oddsid,
				b.winlost - b.actual_stake as winlost,
				b.PlayerComm ,
				--b.Odds,
				CASE WHEN (b.bettype IN (1,2,3,7,12,8,20)	
									OR b.bettype BETWEEN 81 AND 88
									OR b.bettype BETWEEN 90 AND 120)
									THEN 
											CASE WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
												 WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
												 WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
																		CASE 
																			WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																			WHEN b.odds >=0 THEN (1 + b.odds) END
												 WHEN OddsType = 5 THEN --american odds to decimal
																	CASE
																	WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
																	WHEN (b.odds * 100) % 2 = 0 THEN 2
																	WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
											 END 
							  ELSE b.Odds
						 END Odds,
				b.Oddstype,
				1 betcount
			FROM bettrans b WITH (NOLOCK)
			INNER JOIN #bettype bet  ON b.bettype=bet.typeID
			INNER JOIN #recommend re on b.recommend=re.CustID AND b.Currency = re.Currency
			LEFT JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN outright o with(nolock) ON b.matchid = o.orid 
			LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
			WHERE b.winlostdate BETWEEN @TempFromDate AND @todate
				AND (b.custid IN (SELECT * FROM #custID) OR @CustID=0)
				AND b.statusID IN (SELECT StatusID FROM #Status)
		END
		
		;WITH cte_raceinfo
			AS 
			(
				SELECT  o.Orid,r.SportType,r.LeagueID,o.EventDate
				FROM dbo.VSOutright  o WITH (NOLOCK)
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID  
				WHERE o.EventDate BETWEEN @TempFromDate AND @ToDate
			)
				
		UPDATE #Data
		SET sporttype=s.SportType
		FROM #Data  d
			INNER JOIN cte_raceinfo s ON d.oddsid=s.orid
		WHERE d.bettype IN (1231,1232,1233,1237,1238)
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @ToDate
			IF isnull(@Username,'')=''
				BEGIN
					INSERT INTO #Data
					SELECT 
					bk.CustID,
					bk.winlostdate
						,CASE WHEN bk.bettype IN (1220,1235,1236) THEN 186 
							  WHEN bk.bettype IN (9,10,29) THEN 1
							ELSE bk.sporttype 
							END sporttype  
						,bk.bettype
						,bk.currency
						,sum(bk.stake) AS turnover
						,0 as oddsid
						,sum(bk.winlost)  winlost
						,sum(bk.PlayerComm) PlayerComm
						--,bk.Odds
						,CASE WHEN (bettype IN (1,2,3,7,12,8,20)	
									OR bettype BETWEEN 81 AND 88
									OR bettype BETWEEN 90 AND 120)
									THEN 
											CASE WHEN OddsType = 1 THEN odds + 1 --decimal
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
											 END 
							  ELSE bk.Odds
						 END odds
						,bk.oddstype
						,sum(bk.betcount) betcount
					FROM bodb_LicenseeReport.dbo.rptcustomerturnOver bk WITH (NOLOCK,INDEX=CIX_winlostdate) 
					INNER JOIN #recommend re ON bk.recommend=re.custid	AND bk.Currency = re.Currency			
					INNER JOIN #bettype bt ON bk.bettype=bt.typeid	
					INNER JOIN #Status s ON bk.statusID=s.StatusID		
					WHERE bk.winlostdate BETWEEN @fromdate AND @TempToDate				
					GROUP BY  
						bk.CustID,
						bk.winlostdate
						,CASE WHEN bk.bettype IN (1220,1235,1236) THEN 186 
							  WHEN bk.bettype IN (9,10,29) THEN 1
							ELSE bk.sporttype 
							END   
						,bk.bettype
						,bk.currency
						--,bk.Odds
						,CASE WHEN (bettype IN (1,2,3,7,12,8,20)	
									OR bettype BETWEEN 81 AND 88
									OR bettype BETWEEN 90 AND 120)
									THEN 
											CASE WHEN OddsType = 1 THEN odds + 1 --decimal
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
											 END 
							  ELSE bk.Odds
						 END						
						,bk.oddstype
				END
			IF ISNULL(@Username,'')<>''
			BEGIN
				INSERT INTO #Data
				SELECT 
				bk.CustID,
				bk.winlostdate
					,CASE WHEN bk.bettype IN (1220,1235,1236) THEN 186 
						  WHEN bk.bettype IN (9,10,29) THEN 1
						ELSE bk.sporttype 
						END sporttype  
					,bk.bettype
					,bk.currency
					,sum(bk.stake) AS turnover
					,0 as oddsid
					,sum(bk.winlost)  winlost
					,sum(bk.PlayerComm) PlayerComm
					--,bk.Odds
					,CASE WHEN (bettype IN (1,2,3,7,12,8,20)	
							OR bettype BETWEEN 81 AND 88
							OR bettype BETWEEN 90 AND 120)
							THEN 
									CASE WHEN OddsType = 1 THEN odds + 1 --decimal
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
										END 
						ELSE bk.Odds
					END odds
					,bk.oddstype
					,sum(bk.betcount) betcount
				FROM bodb_LicenseeReport.dbo.rptcustomerturnOver bk WITH (NOLOCK,INDEX=IX_recommend)
				INNER JOIN #recommend re ON bk.recommend=re.custid	AND bk.Currency = re.Currency			
				INNER JOIN #bettype bt ON bk.bettype=bt.typeid
				INNER JOIN #Custid cus ON cus.custid = bk.custid
				INNER JOIN #Status s ON bk.StatusID=s.statusid
				WHERE bk.winlostdate BETWEEN @fromdate AND @TempToDate
				GROUP BY  
					bk.CustID,
					bk.winlostdate
					,CASE WHEN bk.bettype IN (1220,1235,1236) THEN 186 
						  WHEN bk.bettype IN (9,10,29) THEN 1
						ELSE bk.sporttype 
						END   
					,bk.bettype
					,bk.currency
					--,bk.Odds
					,CASE WHEN (bettype IN (1,2,3,7,12,8,20)	
							OR bettype BETWEEN 81 AND 88
							OR bettype BETWEEN 90 AND 120)
							THEN 
									CASE WHEN OddsType = 1 THEN odds + 1 --decimal
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
										END 
						ELSE bk.Odds
					END
					,bk.oddstype
			END
		END
		SELECT 
			e.exchangeid
			,e.Code
			INTO #exchange
		FROM exchange e WITH (NOLOCK)
		WHERE e.exchangeid IN (SELECT Currency FROM #Data)
		
		CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data(CustID,bettype,currency,Sporttype,Odds)
		
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
			ROW_NUMBER() over(order by B.WINLOSTDATE desc ,ISNULL(substring(c.username2,charindex ('$',c.username2,1)+1,len(c.username2)),c.username) asc
			) AS RowNum,
			b.winlostdate,
			ISNULL(substring(c.username2,charindex ('$',c.username2,1)+1,len(c.username2)),c.username) as username,
			CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN 'INH'
				ELSE e.Code END AS Currency,
			b.sporttype,		
			CASE WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299) THEN  N'VS - '+typenamee + CASE WHEN typeid = 1204 THEN '(Soccer)'
																					WHEN typeid = 1235 THEN '(Tennis)'
																					ELSE ''
																				END
				 ELSE  bt.typenamee
			END AS bettype,
			sum(b.betcount) AS Betcount,
			sum(b.turnover) AS Turnover,
			sum(b.winlost) AS Winlost,
			SUM(PlayerComm) AS PlayerComm
			
		FROM #Data b
			INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  AS c with (nolock) ON b.CustID=c.CustID  
			INNER JOIN #bettype bt WITH (NOLOCK) ON b.bettype = bt.typeid
			INNER JOIN #exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
			INNER JOIN #ProductID p ON b.Sporttype=p.sportID
		WHERE 
			 b.Odds >= @Odds
		GROUP BY 
			b.winlostdate,	
			ISNULL(substring(c.username2,charindex ('$',c.username2,1)+1,len(c.username2)),c.username),
			CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN 'INH'
				ELSE e.Code END,
			c.username,	
			b.sporttype,	
			b.bettype,
			CASE WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + bt.typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299) THEN  N'VS - '+typenamee + CASE WHEN typeid = 1204 THEN '(Soccer)'
																					WHEN typeid = 1235 THEN '(Tennis)'
																					ELSE ''
																				END
				 ELSE  bt.typenamee
			END
			)A
		
		ORDER BY
			CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
				WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
				ELSE '0' END
		
		select Row_number () over (order by ReportBy desc,Username asc) as rownum
				,ReportBy,  
				username
		into #Row_num
		FROM #result 	
		GROUP BY 
			ReportBy,  
			username
	--- Data Detail 
		SELECT *
		INTO #return
		FROM
		(
		SELECT  
			b.rownum RowNo,
			a.ReportBy,  
			a.username,
			Currency,
			sporttype,
			bettype,
			SUM(Betcount) Betcount ,
			SUM(Turnover) Turnover,
			SUM(Winlost) Winlost,
			SUM(PlayerComm) PlayerComm
		FROM #result a 
		inner join #Row_num b on a.ReportBy=b.ReportBy and a.username=b.username
		GROUP BY 
			b.rownum,
			a.ReportBy,  
			a.username,
			Currency,
			sporttype,
			bettype
		) B
		
		SELECT RowNo,			
			ReportBy,  
			username,
			Currency,
			sporttype,
			bettype,
			Betcount ,
			Turnover,
			Winlost,
			PlayerComm
		FROM #return	
		WHERE ( RowNo between @RowStart AND @RowEnd	AND  @IsExportExcel=0) OR (@IsExportExcel=1 AND RowNo<65000)	
		ORDER BY RowNo
		
		SELECT @TotalRow=COUNT(1)
		FROM #Row_num
				
				
		SELECT sum(betcount) Sumbetcount,
			   sum(Turnover) SumTurnover,
			   sum(Winlost) SumWinlost ,
			   sum(PlayerComm) SumComm,
			   @TotalRow  TotalRows
		FROM #return
		WHERE (@IsExportExcel=0) OR (@IsExportExcel=1 AND RowNo<65000)
		-----------------------
		DROP TABLE #return	
		DROP TABLE #Data	
		DROP TABLE #result	
		DROP TABLE #bettype
		DROP TABLE #custID
		DROP TABLE #recommend
		DROP TABLE #Row_num
		DROP TABLE #exchange
	END
----------------------
DROP TABLE #ProductID
DROP TABLE #BettypeID
DROP TABLE #Status
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] 