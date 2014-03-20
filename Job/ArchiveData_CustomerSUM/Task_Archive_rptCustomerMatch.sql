
ALTER PROCEDURE [dbo].[Task_Archive_rptCustomerMatch]
AS

/*	Creator: Victor
	Task : Archive old data in table rptCustomerMatch
	DB: DBLIC.bodb_Licensee
	Date: 2014-03-20
		             
	Param's Explanation:
	Revisions:	
*/

DECLARE @WeekDay INT

SET DATEFIRST 7
SELECT @WeekDay = DATEPART(WEEKDAY,CURRENT_TIMESTAMP)

-- Only archive on Tuesday everyweek
IF (@WeekDay != 3)
BEGIN
	RETURN
END

-- Check old data to archive
DECLARE @ArchiveDate DATE

SELECT @ArchiveDate = DATEADD(MONTH,-3,CONVERT(VARCHAR(8),CURRENT_TIMESTAMP,120) + '01')

DECLARE @WinlostDate DATE
SELECT @WinlostDate = MIN(Winlostdate) FROM bodb_LicenseeReport.dbo.rptCustomerMatch (NOLOCK)

IF (@WinlostDate >= @ArchiveDate)
BEGIN
	PRINT 'There is no old data to move!'
	RETURN
END

-- Move old data to archive table
DECLARE @BatchCount SMALLINT
DECLARE @BatchRecord INT

SELECT @BatchCount = 20, @BatchRecord = 100000

CREATE TABLE #tmpDeleted (	[custid] [int] NOT NULL,
							[matchid] [int] NULL,
							[oddsid] [int] NULL,
							[Leagueid] [int] NULL,
							[bettype] [smallint] NULL,
							[odds] [money] NULL,
							[oddstype] [tinyint] NULL,
							[statusid] [tinyint] NULL,
							[stake] [money] NULL,
							[winlost] [money] NULL,
							[winlostdate] [datetime] NULL,
							[awinlost] [money] NULL,
							[comm] [money] NULL,
							[playercomm] [money] NULL,
							[recommend] [int] NULL,
							[isBA] [bit] NULL,
							[betcount] [smallint] NULL )

DECLARE @iBatch TINYINT
SELECT @iBatch = @BatchCount

WHILE (@WinlostDate < @ArchiveDate AND @iBatch > 0)
BEGIN
	TRUNCATE TABLE #tmpDeleted

	DELETE TOP (@BatchRecord) 
	FROM bodb_LicenseeReport.dbo.rptCustomerMatch
	OUTPUT DELETED.custid, DELETED.matchid, DELETED.oddsid, DELETED.Leagueid, DELETED.bettype, DELETED.odds, 
			DELETED.oddstype, DELETED.statusid, DELETED.stake, DELETED.winlost, DELETED.winlostdate, DELETED.awinlost,
			DELETED.comm, DELETED.playercomm, DELETED.recommend, DELETED.isBA, DELETED.betcount INTO #tmpDeleted
	WHERE winlostdate = @WinlostDate

	INSERT INTO bodb_LicenseeReport.dbo.rptCustomerMatch_bk
	SELECT * FROM #tmpDeleted

	IF (@@RowCount = 0)
	BEGIN
		SELECT @WinlostDate = MIN(Winlostdate) FROM bodb_LicenseeReport.dbo.rptCustomerMatch (NOLOCK)
	END
	ELSE
	BEGIN
		SELECT @iBatch = @iBatch - 1
		WAITFOR DELAY '00:00:01'
	END
END

DROP TABLE #tmpDeleted