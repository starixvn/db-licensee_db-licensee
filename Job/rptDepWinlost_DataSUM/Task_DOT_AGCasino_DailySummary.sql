ALTER PROCEDURE [dbo].[Task_DOT_AGCasino_DailySummary]
	@winlostdate DATETIME
AS
/*   
Created: 20140911@Victor
Task: Summary AG Casino data and insert into rptDepWinlost_AGCasino
DB: DBACC/bodb02
Original:
Revisions:
	- 20141017@Victor: remove RAISEERROR statement to avoid affection to rptDepWinlost Summary job
	- 20141121@Don: Adjustment to serve to change KeenOcean's currency RMB to HK$
Param's Explanation:
	- @winlostdate: The date need to summary
*/  
SET NOCOUNT ON
BEGIN TRY

	DECLARE @BackupDay DATE
	SELECT @BackupDay = ISNULL(MIN(Winlostdate),'') FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_AGCasino

	CREATE TABLE #TicketData (	custid			INT,
								sporttype		SMALLINT,
								currency		INT,
								isVipGame		INT,
								turnover		MONEY,
								drawTO			MONEY,
								winlost			MONEY,
								playercomm		MONEY,
								betCount		INT,
								drawBetCount	INT)

	IF @winlostdate >= @BackupDay -- Get data in bettrans_AGCasino table
	BEGIN
		INSERT INTO #TicketData (custid, sporttype, currency, isVipGame, turnover, drawTO, winlost, playercomm, betCount, drawBetCount)
		SELECT b.CustID, 
			250 AS SportType,
			b.currency,
			isVIPGame,
			ISNULL(SUM(b.Stake),0) AS Turnover,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN b.Stake ELSE 0 END),0) AS DrawTO,
			ISNULL(SUM(b.Winlost - b.Actual_Stake),0) AS Winlost,
			0 AS PlayerComm,
			ISNULL(COUNT(*),0) AS Betcount,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN 1 ELSE 0 END),0) AS DrawBetCount
		FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_AGCasino b WITH (ROWLOCK)
		WHERE Winlostdate = @winlostdate
		GROUP BY b.CustID, b.currency, isVIPGame
	END
	ELSE -- Get data in bettrans_AGCasino_bk table
	BEGIN
		INSERT INTO #TicketData (custid, sporttype, currency, isVipGame, turnover, drawTO, winlost, playercomm, BetCount, drawBetCount)
		SELECT b.CustID, 
			250 AS SportType,
			b.currency,
			isVIPGame,
			ISNULL(SUM(b.Stake),0) AS Turnover,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN b.Stake ELSE 0 END),0) AS DrawTO,
			ISNULL(SUM(b.Winlost - b.Actual_Stake),0) AS Winlost,
			0 AS PlayerComm,
			ISNULL(COUNT(*),0) AS Betcount,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN 1 ELSE 0 END),0) AS DrawBetCount
		FROM bodb_archive.dbo.bettrans_AGCasino_bk b WITH (ROWLOCK)
		WHERE Winlostdate = @winlostdate
		GROUP BY b.CustID, b.currency, isVIPGame
	END

	-- Insert data to rptDepWinlost_AGCasino
	DELETE FROM bodb_report.dbo.rptDepWinlost_AGCasino WHERE Winlostdate = @Winlostdate

	INSERT INTO bodb_report.dbo.rptDepWinlost_AGCasino (winlostdate, custid, sporttype, currency, turnover, drawTO, 
														winlost, playercomm, BetCount, drawBetCount, IsVIPGame)
	SELECT @winlostdate, custid, sporttype, currency, turnover, drawTO, 
		winlost, playercomm, BetCount, drawBetCount, IsVIPGame
	FROM #TicketData

	DROP TABLE #TicketData
END TRY
BEGIN CATCH
	-- This SPs called from another SP in rptDepwinlost Summary process, failure of this SP should not affect to that process
	--RAISERROR(15000,1,1,'Error occured in summarizing AG Casino data.')
	PRINT 'Error occured in AGCasino summary data process: ERR_CODE: '+ CAST(ERROR_NUMBER() AS VARCHAR(20)) + ', ERR_MSG: ' + ERROR_MESSAGE()
	RETURN
END CATCH