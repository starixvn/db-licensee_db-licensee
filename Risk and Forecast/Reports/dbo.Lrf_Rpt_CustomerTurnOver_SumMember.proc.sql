
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

 
CREATE PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver_SumMember]
(
	@pStartDate		DATE
	,@pEndDate 		DATE
	,@MoveBetsDay 	SMALLDATETIME
	,@Odds 			FLOAT
	,@ReportBy  	TINYINT
) 
WITH RECOMPILE
AS
/*	
Created: 20150603@Bobby
Task: Customer Performance Report
DB: DBEXT/BODB02
Revision:
	- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
	- 20151223@Jim: Add "Effective Betting Value" in Customer Turnover report [Redmine: #45736]
	- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
Parameter's Explanation:
			
*/
BEGIN
	SET NOCOUNT ON;

	--GET sum member detial
	IF(@pEndDate > @MoveBetsDay)
	BEGIN
		INSERT INTO #custData
		SELECT c.rowno
			, c.winlostdate 
			, c.custid
			, rec.currency
			, b.sporttype
			, b.bettype
			, SUM(1) 			as betcount
			, SUM(b.stake) 		as turnover 
			, SUM(b.winlost) 	as winlost
			,SUM (b.BetEffective) as BetEffective
			, SUM(b.playercomm) as playercomm
			, c.whticket
		FROM #tempBettrans b
			INNER JOIN #recommend rec
			ON b.Recommend	= rec.CustID
			INNER JOIN #tempCustPaging c 
			ON  b.custid		= c.custid 
			AND c.winlostdate 	= CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
									ELSE b.winlostdate
								END
		
		WHERE b.winlostdate BETWEEN @pStartDate AND @pEndDate
		
		GROUP BY
			c.rowno
			,c.winlostdate 
			,c.custid
			,rec.currency
			,b.sporttype
			,b.bettype
			,c.whticket
			
		OPTION (RECOMPILE)
	END

	IF(@pStartDate <= @MoveBetsDay)
	BEGIN
		IF ( @odds = 0 )
		BEGIN
			INSERT INTO #custData
			SELECT 
				c.rowno
				, c.winlostdate 
				, c.custid
				, rec.currency
				, CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END AS sporttype  
				, b.bettype
				, SUM(b.betcount) as betcount
				, SUM(b.stake) as turnover 
				, SUM(b.winlost) as winlost
				, SUM(b.BetEffective) As BetEffective
				, SUM(b.playercomm) as playercomm
				, c.whticket
				
			FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH (NOLOCK)
				INNER JOIN #recommend rec
				ON b.Recommend	= rec.CustID
				INNER JOIN #tempCustPaging c 
				ON  b.custid	= c.custid
				AND c.winlostdate 	= CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
										ELSE b.winlostdate
									END				
				INNER JOIN #bettype bt
				ON b.bettype 	=  bt.typeid
				INNER JOIN #Status st
				ON b.StatusID 	=  st.StatusID
				INNER JOIN #ProductID p 
				ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END			= p.sportID
					
			WHERE b.winlostdate BETWEEN @pStartDate AND @pEndDate
				
			GROUP BY
				c.rowno
				, c.winlostdate 
				, c.custid
				, rec.currency
				, CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END
				,b.bettype
				,c.whticket
			
			OPTION (RECOMPILE)
		END
		
		--Has Odds Value
		IF ( @odds > 0 )
		BEGIN
			INSERT INTO #custData
			SELECT 
				c.rowno
				, c.winlostdate 
				, c.custid
				, rec.currency
				, CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END AS sporttype  
				, b.bettype
				, SUM(b.betcount) as betcount
				, SUM(b.stake) as turnover 
				, SUM(b.winlost) as winlost
				, SUM(b.BetEffective) As BetEffective
				, SUM(b.playercomm) as playercomm
				, c.whticket
				
			FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH (NOLOCK)
				INNER JOIN #recommend rec
				ON b.Recommend	= rec.CustID
				INNER JOIN #tempCustPaging c 
				ON  b.custid	= c.custid 
				AND c.winlostdate 	= CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
										ELSE b.winlostdate
									END
				INNER JOIN #bettype bt
				ON b.bettype 	=  bt.typeid
				INNER JOIN #Status st
				ON b.StatusID 	=  st.StatusID
				INNER JOIN #ProductID p 
				ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END			= p.sportID
					
			WHERE b.winlostdate BETWEEN @pStartDate AND @pEndDate
				AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even
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
				
			GROUP BY
				c.rowno
				, c.winlostdate 
				, c.custid
				, rec.currency
				, CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END
				,b.bettype
				,c.whticket
			
			OPTION (RECOMPILE)
		END
	END

	RETURN;
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver_SumMember] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver_SumMember] TO [bodbLicenseeNet]
GO 
