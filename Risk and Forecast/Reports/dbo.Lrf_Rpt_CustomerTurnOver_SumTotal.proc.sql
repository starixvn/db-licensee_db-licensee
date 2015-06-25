USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_CustomerTurnOver]    Script Date: 6/3/2015 4:25:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver_SumTotal]
(
	@searchCust 	BIT = 0
	,@FromDate 		SMALLDATETIME
	,@tempFromDate 	SMALLDATETIME
	,@ToDate 		SMALLDATETIME
	,@tempToDate 	SMALLDATETIME
	,@MoveBetsDay 	SMALLDATETIME
	,@Odds 			FLOAT
	,@ReportBy  	TINYINT   =  1 
)
AS
BEGIN
	SET NOCOUNT ON;

	IF( @searchCust = 1 )
	BEGIN
		IF( @Todate > @MoveBetsDay AND NOT EXISTS(SELECT TOP 1 1 FROM #tempSumTotal WHERE whticket = 1 ) )
		BEGIN
			IF ( @odds = 0 )
			BEGIN
				INSERT INTO #tempSumTotal
				SELECT 1				AS WhTicket
					, SUM(1)			AS betcount
					, SUM(stake) 		AS turnover
					, SUM(b.winlost - b.actual_stake) AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN #recommend rec 
					ON b.Recommend	= rec.CustID 
					INNER JOIN #tempCust  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					--EventType =  1
					LEFT JOIN dbo.match m WITH (NOLOCK) 
					ON b.matchid 		= m.matchid
					AND bt.EventType 	= 1
					--EventType =  2
					LEFT JOIN dbo.outright o with(nolock) 
					ON b.matchid 		= o.orid 
					AND bt.EventType 	= 2
					LEFT JOIN dbo.league l with(nolock) 
					ON o.leagueid 		= l.leagueid
					--EventType =  3
					LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
					ON b.oddsid			= vs.Orid
					AND bt.EventType 	= 3
					LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
					ON vs.EventID  		= r.EventID
					LEFT JOIN #ProductID p 
					ON (
						bt.EventType	= 1 AND m.sporttype	= p.sportID
						OR bt.EventType = 2 AND l.sporttype	= p.sportID
						OR bt.EventType = 3 AND r.sporttype	= p.sportID
						OR bt.EventType = 0 AND 1			= p.sportID
					)

				WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
					AND p.sportID IS NOT NULL
			END
			
			-- Has Odds Value
			IF (@odds > 0 )
			BEGIN
				INSERT INTO #tempSumTotal
				SELECT 1				AS WhTicket
					, SUM(1)			AS betcount
					, SUM(stake) 		AS turnover
					, SUM(b.winlost - b.actual_stake) AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN #recommend rec 
					ON b.Recommend	= rec.CustID 
					INNER JOIN #tempCust  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					--EventType =  1
					LEFT JOIN dbo.match m WITH (NOLOCK) 
					ON b.matchid 		= m.matchid
					AND bt.EventType 	= 1
					--EventType =  2
					LEFT JOIN dbo.outright o with(nolock) 
					ON b.matchid 		= o.orid 
					AND bt.EventType 	= 2
					LEFT JOIN dbo.league l with(nolock) 
					ON o.leagueid 		= l.leagueid
					--EventType =  3
					LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
					ON b.oddsid			= vs.Orid
					AND bt.EventType 	= 3
					LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
					ON vs.EventID  		= r.EventID
					LEFT JOIN #ProductID p 
					ON (
						bt.EventType	= 1 AND m.sporttype	= p.sportID
						OR bt.EventType = 2 AND l.sporttype	= p.sportID
						OR bt.EventType = 3 AND r.sporttype	= p.sportID
						OR bt.EventType = 0 AND 1			= p.sportID
					)

				WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
					AND p.sportID IS NOT NULL
					AND	CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
									OR b.bettype BETWEEN 81 AND 88
									OR b.bettype BETWEEN 90 AND 120
									OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								)
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
						END >= @odds
			END
				
		END
		
		IF(@FromDate <= @MoveBetsDay AND NOT EXISTS(SELECT TOP 1 1 FROM #tempSumTotal WHERE whticket = 2 ) )
		BEGIN
			IF( @odds = 0 )
			BEGIN
				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS turnover
					, SUM(b.winlost)  	AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
					INNER JOIN #recommend rec
					ON b.Recommend	= rec.CustID
					INNER JOIN #tempCust  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					INNER JOIN #ProductID p 
					ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
							ELSE b.sporttype 
						END			= p.sportID
				WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
				
			END 
			
			-- Has Odds Value
			IF( @odds > 0 )
			BEGIN
				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS turnover
					, SUM(b.winlost)  	AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
					INNER JOIN #recommend rec
					ON b.Recommend	= rec.CustID
					INNER JOIN #tempCust  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					INNER JOIN #ProductID p 
					ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
							ELSE b.sporttype 
						END			= p.sportID
				WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
					AND CASE WHEN (	b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							)
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
					END >= @odds
			END
		END	
	END
	-- VIEW all member
	IF (@searchCust = 0)
	BEGIN
		
		IF( @Todate > @MoveBetsDay AND NOT EXISTS(SELECT TOP 1 1 FROM #tempSumTotal WHERE whticket = 1 ) )
		BEGIN
			IF ( @odds = 0 )
			BEGIN
			
				INSERT INTO #tempSumTotal
				SELECT 1				AS WhTicket
					, SUM(1)			AS betcount
					, SUM(stake) 		AS turnover
					, SUM(b.winlost - b.actual_stake) AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN #recommend rec 
					ON b.Recommend	= rec.CustID 
					INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					--EventType =  1
					LEFT JOIN dbo.match m WITH (NOLOCK) 
					ON b.matchid 		= m.matchid
					AND bt.EventType 	= 1
					--EventType =  2
					LEFT JOIN dbo.outright o with(nolock) 
					ON b.matchid 		= o.orid 
					AND bt.EventType 	= 2
					LEFT JOIN dbo.league l with(nolock) 
					ON o.leagueid 		= l.leagueid
					--EventType =  3
					LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
					ON b.oddsid			= vs.Orid
					AND bt.EventType 	= 3
					LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
					ON vs.EventID  		= r.EventID
					LEFT JOIN #ProductID p 
					ON (
						bt.EventType	= 1 AND m.sporttype	= p.sportID
						OR bt.EventType = 2 AND l.sporttype	= p.sportID
						OR bt.EventType = 3 AND r.sporttype	= p.sportID
						OR bt.EventType = 0 AND 1			= p.sportID
					)

				WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
					AND p.sportID IS NOT NULL
				
			END
					
			-- Has Odds Value
			IF ( @odds > 0)
			BEGIN
				INSERT INTO #tempSumTotal
				SELECT 1				AS WhTicket
					, SUM(1)			AS betcount
					, SUM(stake) 		AS turnover
					, SUM(b.winlost - b.actual_stake) AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN #recommend rec 
					ON b.Recommend	= rec.CustID 
					INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					--EventType =  1
					LEFT JOIN dbo.match m WITH (NOLOCK) 
					ON b.matchid 		= m.matchid
					AND bt.EventType 	= 1
					--EventType =  2
					LEFT JOIN dbo.outright o with(nolock) 
					ON b.matchid 		= o.orid 
					AND bt.EventType 	= 2
					LEFT JOIN dbo.league l with(nolock) 
					ON o.leagueid 		= l.leagueid
					--EventType =  3
					LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
					ON b.oddsid			= vs.Orid
					AND bt.EventType 	= 3
					LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
					ON vs.EventID  		= r.EventID
					LEFT JOIN #ProductID p 
					ON (
						bt.EventType	= 1 AND m.sporttype	= p.sportID
						OR bt.EventType = 2 AND l.sporttype	= p.sportID
						OR bt.EventType = 3 AND r.sporttype	= p.sportID
						OR bt.EventType = 0 AND 1			= p.sportID
					)

				WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
					AND p.sportID IS NOT NULL
					AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
									OR b.bettype BETWEEN 81 AND 88
									OR b.bettype BETWEEN 90 AND 120
									OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								)
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
						END >= @odds
			END					
		END

		IF(@FromDate <= @MoveBetsDay AND NOT EXISTS(SELECT TOP 1 1 FROM #tempSumTotal WHERE whticket = 2) )
		BEGIN
			IF( @odds = 0 )
			BEGIN
			
				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS turnover
					, SUM(b.winlost)  	AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
					INNER JOIN #recommend rec
					ON b.Recommend	= rec.CustID
					INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					INNER JOIN #ProductID p 
					ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
							ELSE b.sporttype 
						END			= p.sportID
				WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
				
			END
	
			-- Has Odds Value
			IF (@odds > 0 )
			BEGIN
			
				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS turnover
					, SUM(b.winlost)  	AS winlost
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
					INNER JOIN #recommend rec
					ON b.Recommend	= rec.CustID
					INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
					ON b.custid 	= c.custid
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					INNER JOIN #ProductID p 
					ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
							ELSE b.sporttype 
						END			= p.sportID
				WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
					AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							)
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
					END >= @odds
			END
		END
	END
	RETURN;
END
GO 
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver_SumTotal] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver_SumTotal] TO [vnteam] 
GO