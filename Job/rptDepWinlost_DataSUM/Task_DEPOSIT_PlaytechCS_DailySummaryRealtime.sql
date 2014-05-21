ALTER PROCEDURE [dbo].[Task_DEPOSIT_PlaytechCS_DailySummaryRealtime]
AS
/*   
 Task : Summary data for PlaytechCasino and insert into rptDepWinlost_PlaytechCS (DB054 Realtime Job)
 DB: DB054/bodb02  
 Revisions:   
	- 20140515@Victor: create SP
	- 20140519@Victor: update NetGaming formula
	- 20140521@Victor: Get customer WL in a whole day instead of new tickets only
 Param's Explanation:  

 - @winlostdate: The date need to summary
*/  
SET NOCOUNT ON
BEGIN TRY
	CREATE TABLE #PlaytechData (custid INT,
								sporttype SMALLINT,
								turnover MONEY,
								drawTO MONEY,
								winlost MONEY,
								playercomm MONEY,
								BetCount INT,
								drawBetCount INT,
								Outstanding MONEY,
								PShare MONEY,
								PWin MONEY,
								NetGaming MONEY)

	CREATE TABLE #CustList (custid INT)

	DECLARE @_tstamp BINARY(8),
			@new_tstamp BINARY(8)

	DECLARE @Today DATE
	SELECT @Today = GETDATE()

	SELECT @_tstamp = CAST(CAST(ISNULL(vvalue,0) AS BIGINT) AS BINARY(8))
	FROM dbo.systemsettings2 WITH(ROWLOCK) 
	WHERE vname = 'Task_PlaytechCS_tstamp'

	SELECT @new_tstamp = MAX(tstamp)
	FROM (	SELECT TOP (1000) tstamp 
			FROM DBPTCS.bodb_playtechCS.dbo.bettrans_PlaytechCS 
			WHERE tstamp > @_tstamp ORDER BY tstamp) a

	IF (@new_tstamp IS NOT NULL AND @new_tstamp != 0)
	BEGIN
		
		INSERT INTO #CustList (CustID)
		SELECT DISTINCT CustId FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH (NOLOCK) WHERE tstamp > @_tstamp AND tstamp <= @new_tstamp AND Winlostdate = @Today

		INSERT INTO #PlaytechData (custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, drawBetCount, Outstanding, PShare, PWin, NetGaming)
		SELECT 
			b.CustID, 
			254 AS SportType,
			ISNULL(SUM(b.Stake),0) AS Turnover,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN b.Stake ELSE 0 END),0) AS DrawTO,
			ISNULL(SUM(b.Winlost - b.Actual_Stake),0) AS Winlost,
			0 AS PlayerComm,
			ISNULL(COUNT(*),0) AS Betcount,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN 1 ELSE 0 END),0) AS DrawBetCount,
			0 AS Outstanding,
			ISNULL(SUM(b.ProgressiveShare),0) AS ProgressiveShare,
			ISNULL(SUM(b.ProgressiveWin),0) AS ProgressiveWin,
			ISNULL(SUM(-b.Winlost + b.Actual_Stake - b.ProgressiveShare + b.ProgressiveWin),0) AS NetGaming
		FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH (ROWLOCK)
		WHERE b.CustID IN (SELECT custid FROM #CustList) AND Winlostdate = @Today
		GROUP BY b.CustID

		MERGE dbo.rptDepWinlost_PlaytechCS_staging AS target
		USING (SELECT @Today AS Winlostdate,custid, sporttype, turnover, drawTO, winlost, playercomm, 
					BetCount, drawBetCount, Outstanding, PShare, PWin, NetGaming
				FROM #PlaytechData) 
			   AS source (Winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, 
					BetCount, drawBetCount, Outstanding, PShare, PWin, NetGaming)

				ON (target.winlostdate = source.winlostdate AND target.custid = source.custid)
			WHEN MATCHED THEN 
				 UPDATE SET	target.sporttype = source.sporttype,
							target.turnover = source.turnover,
							target.drawTO = source.drawTO,
							target.winlost = source.winlost,
							target.playercomm = source.playercomm,
							target.BetCount = source.BetCount,
							target.drawBetCount = source.drawBetCount,
							target.Outstanding = source.Outstanding,
							target.ProgressiveShare = source.PShare,
							target.ProgressiveWin = source.PWin,
							target.NetGaming = source.NetGaming
			WHEN NOT MATCHED THEN	
				INSERT ( Winlostdate,custid, sporttype, turnover, drawTO, winlost, playercomm, 
						BetCount, drawBetCount, Outstanding, ProgressiveShare, ProgressiveWin, NetGaming)
				VALUES (source.winlostdate, source.custid, source.sporttype, source.turnover, source.drawTO, source.winlost, source.playercomm,
						source.betcount, source.drawBetCount, source.Outstanding, source.PShare, source.PWin, source.NetGaming);

		INSERT INTO dbo.rptDepWinlostByProduct_staging (winlostdate, custid, sporttype, turnover, 
														drawTO, winlost, playercomm, BetCount, Outstanding)
		SELECT @Today, custid, sporttype, turnover, 
			drawTO, winlost, playercomm, BetCount, Outstanding
		FROM #PlaytechData

		UPDATE dbo.systemsettings2 WITH(ROWLOCK, UPDLOCK)
		SET vvalue = CAST(CAST(@new_tstamp as bigint) as varchar(200))
		WHERE vname = 'Task_PlaytechCS_tstamp'
	END

	DROP TABLE #PlaytechData
	DROP TABLE #CustList
END TRY
BEGIN CATCH
	-- This SPs called from another SP in rptDepwinlost Summary process, failure of this SP should not affect to that process
	RAISERROR(15000,1,1,'Error occured in summarizing Playtech Casino data.')
	RETURN
END CATCH