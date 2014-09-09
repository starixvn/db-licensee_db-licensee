ALTER PROCEDURE DBA_PTCS_GenDataToRptDepWinlost_PlaytechCS
	@Winlostdate DATE

/**
 * Created by	: @Victor
 * Date			: 20140515
 * Task			: Gen Playtech Casino Data to RptDepWinlost_PlaytechCS manually 
 * DB			: DBACC.bodb02
 * Revisions	:
 * Parameters:
 *  
 */
AS
BEGIN
	DECLARE @BackupDay DATE
	SELECT @BackupDay = ISNULL(MIN(Winlostdate),'') FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_PlaytechCS

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

	IF @winlostdate >= @BackupDay -- Get data in bettrans_PlaytechCS table
	BEGIN
		INSERT INTO #PlaytechData (custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, drawBetCount, Outstanding, PShare, PWin, NetGaming)
		SELECT b.CustID, 
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
			ISNULL(SUM(b.Winlost - b.Actual_Stake - b.ProgressiveShare + b.ProgressiveWin),0) AS NetGaming
		FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH (ROWLOCK)
		WHERE Winlostdate = @winlostdate
		GROUP BY b.CustID
	END
	ELSE -- Get data in bettrans_PlaytechCS_bk table
	BEGIN
		INSERT INTO #PlaytechData (custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, drawBetCount, Outstanding, PShare, PWin, NetGaming)
		SELECT b.CustID, 
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
			ISNULL(SUM(b.Winlost - b.Actual_Stake - b.ProgressiveShare + b.ProgressiveWin),0) AS NetGaming
		FROM bodb_archive.dbo.bettrans_PlaytechCS_bk b WITH (ROWLOCK)
		WHERE Winlostdate = @winlostdate
		GROUP BY b.CustID
	END

	-- Insert data to rptDepWinlost_PlaytechCS
	DELETE FROM bodb_report.dbo.rptDepWinlost_PlaytechCS WHERE Winlostdate = @Winlostdate

	INSERT INTO bodb_report.dbo.rptDepWinlost_PlaytechCS (winlostdate,custid,sporttype,turnover,drawTO,winlost,playercomm,BetCount,
															drawBetCount,Outstanding,ProgressiveShare,ProgressiveWin,NetGaming)
	SELECT @winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, 
		drawBetCount, Outstanding, PShare, PWin, NetGaming
	FROM #PlaytechData

	-- Insert data to rptDepWinlostByProduct
	/*DELETE FROM bodb_report.dbo.rptDepWinlostByProduct WHERE Winlostdate = @Winlostdate AND sporttype = 254 

	INSERT INTO bodb_report.dbo.rptDepWinlostByProduct (winlostdate, custid, sporttype, turnover, 
														drawTO, winlost, playercomm, BetCount, Outstanding)
	SELECT @winlostdate, custid, sporttype, turnover, 
		drawTO, winlost, playercomm, BetCount, Outstanding
	FROM #PlaytechData

	DROP TABLE #PlaytechData
	*/
END