ALTER PROCEDURE DBA_PTCS_GenDataToRptDepWinlostByProduct
	@Winlostdate DATE

/**
 * Created by	: @Victor
 * Date			: 20140425
 * Task			: Gen Playtech Casino Data to RptDepWinlostByProduct manually 
 * DB			: DBPTCS.bodb_PlaytechCS
 * Revisions	:
	- 20140514@Victor: Move bettrans_PlaytechCS_bk table to bodb_archive

 * Parameters:
 *  
 */
AS
BEGIN
	CREATE TABLE #rptDepWinlostByProduct (custid INT, winlostdate DATE, sporttype TINYINT, turnover MONEY, winlost MONEY, BetCount INT, drawTO MONEY, playercomm MONEY, Outstanding MONEY)

	DECLARE @BackupDay DATE
	SELECT @BackupDay = ISNULL(MIN(Winlostdate),'') FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_PlaytechCS

	IF @Winlostdate >= @BackupDay -- Get data in bettrans_PlaytechCS table
	BEGIN
		INSERT INTO #rptDepWinlostByProduct (custid, winlostdate, sporttype, turnover, winlost, BetCount, drawTO, playercomm, Outstanding)
		SELECT b.CustID, b.Winlostdate,
			254 AS SportType,
			ISNULL(SUM(b.Stake),0) AS Turnover,
			ISNULL(SUM(b.Winlost - b.Actual_Stake),0) AS Winlost,
			ISNULL(COUNT(*),0) AS Betcount,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN b.Stake ELSE 0 END),0) AS drawTO,
			0,0
		FROM bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH (ROWLOCK)
		WHERE winlostdate = @winlostdate
		GROUP BY b.CustID, b.winlostdate
	END/* 
	ELSE -- Get data in bettrans_PlaytechCS_bk table
	BEGIN
		INSERT INTO #rptDepWinlostByProduct (custid, winlostdate, sporttype, turnover, winlost, BetCount, drawTO, playercomm, Outstanding)
		SELECT b.CustID, b.Winlostdate,
			254 AS SportType,
			ISNULL(SUM(b.Stake),0) AS Turnover,
			ISNULL(SUM(b.Winlost - b.Actual_Stake),0) AS Winlost,
			ISNULL(COUNT(*),0) AS Betcount,
			ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN b.Stake ELSE 0 END),0) AS drawTO,
			0,0
		FROM DBARC.bodb_archive.dbo.bettrans_PlaytechCS_bk b WITH (ROWLOCK)
		WHERE winlostdate = @winlostdate
		GROUP BY b.CustID, b.winlostdate
	END*/
	
	INSERT INTO DBRPT.bodb_Report.dbo.rptDepWinlostByProduct (winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, Outstanding)
	SELECT winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, Outstanding
	FROM #rptDepWinlostByProduct d
	WHERE NOT EXISTS (	SELECT 1 FROM DBRPT.bodb_Report.dbo.rptDepWinlostByProduct rp WITH (NOLOCK) 
						WHERE rp.custID = d.custid AND rp.winlostdate = d.winlostdate AND rp.sporttype = d.sporttype)

	UPDATE rp
	SET turnover = d.turnover,
		winlost = d.winlost,
		BetCount = d.BetCount,
		drawTo = d.drawTO,
		PlayerComm = d.playercomm,
		Outstanding = d.Outstanding
	FROM #rptDepWinlostByProduct d
		INNER JOIN DBRPT.bodb_Report.dbo.rptDepWinlostByProduct rp WITH (NOLOCK) 
			ON rp.custID = d.custid AND rp.winlostdate = d.winlostdate AND rp.sporttype = d.sporttype
	DROP TABLE #rptDepWinlostByProduct
END