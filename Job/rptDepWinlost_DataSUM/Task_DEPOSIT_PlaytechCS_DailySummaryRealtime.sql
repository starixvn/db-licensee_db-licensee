ALTER PROCEDURE [dbo].[Task_DEPOSIT_PlaytechCS_DailySummaryRealtime]
AS
/*   
 Task : Summary data for PlaytechCasino and insert into rptDepWinlost_PlaytechCS (DB054 Realtime Job)
 DB: DB054/bodb02  
 Revisions:   
	- 20140515@Victor: create SP
	- 20140519@Victor: update NetGaming formula
 Param's Explanation:  

 - @winlostdate: The date need to summary
*/  
SET NOCOUNT ON
BEGIN TRY
	CREATE TABLE #PlaytechData (winlostdate DATETIME,
								custid INT,
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

	DECLARE @_tstamp BINARY(8),
			@new_tstamp BINARY(8)

	SELECT @_tstamp = CAST(CAST(ISNULL(vvalue,0) AS BIGINT) AS BINARY(8))
	FROM dbo.systemsettings2 WITH(ROWLOCK) 
	WHERE vname = 'Task_PlaytechCS_tstamp'

	SELECT @new_tstamp = MAX(tstamp)
	FROM (	SELECT TOP (1000) tstamp 
			FROM DBPTCS.bodb_playtechCS.dbo.bettrans_PlaytechCS 
			WHERE tstamp > @_tstamp ORDER BY tstamp) a

	IF (@new_tstamp IS NOT NULL AND @new_tstamp != 0)
	BEGIN
		INSERT INTO #PlaytechData (winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, drawBetCount, Outstanding, PShare, PWin, NetGaming)
		SELECT b.winlostdate,
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
		WHERE tstamp > @_tstamp AND tstamp <= @new_tstamp
		GROUP BY b.CustID, b.Winlostdate

		INSERT INTO dbo.rptDepWinlost_PlaytechCS_staging (winlostdate,custid,sporttype,turnover,drawTO,winlost,playercomm,BetCount,
															drawBetCount,Outstanding,ProgressiveShare,ProgressiveWin,NetGaming)
		SELECT winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, 
			drawBetCount, Outstanding, PShare, PWin, NetGaming
		FROM #PlaytechData

		INSERT INTO dbo.rptDepWinlostByProduct_staging (winlostdate, custid, sporttype, turnover, 
														drawTO, winlost, playercomm, BetCount, Outstanding)
		SELECT winlostdate, custid, sporttype, turnover, 
			drawTO, winlost, playercomm, BetCount, Outstanding
		FROM #PlaytechData

		UPDATE dbo.systemsettings2 WITH(ROWLOCK, UPDLOCK)
		SET vvalue = CAST(CAST(@new_tstamp as bigint) as varchar(200))
		WHERE vname = 'Task_PlaytechCS_tstamp'
	END

	DROP TABLE #PlaytechData
END TRY
BEGIN CATCH
	-- This SPs called from another SP in rptDepwinlost Summary process, failure of this SP should not affect to that process
	RAISERROR(15000,1,1,'Error occured in summarizing Playtech Casino data.')
	RETURN
END CATCH