
ALTER PROCEDURE [dbo].[Task_Archive_rptCustomerTurnover]
AS

/*	Creator: Victor
	Task : Archive old data in table rptCustomerTurnover
	DB: DB052.bodb_LicenseeReport
	Date: 2014-03-20
		             
	Param's Explanation:
	Revisions:	
*/

DECLARE @WeekDay INT

SET DATEFIRST 7
SELECT @WeekDay = DATEPART(WEEKDAY,CURRENT_TIMESTAMP)

-- Only archive on Tuesday everyweek
IF (@WeekDay != 4)
BEGIN
	RETURN
END

-- Check old data to archive
DECLARE @ArchiveDate DATE

SELECT @ArchiveDate = DATEADD(MONTH,-3,CONVERT(VARCHAR(8),CURRENT_TIMESTAMP,120) + '01')

DECLARE @WinlostDate DATE
SELECT @WinlostDate = MIN(Winlostdate) FROM rptCustomerTurnover (NOLOCK)

IF (@WinlostDate >= @ArchiveDate)
BEGIN
	PRINT 'There is no old data to move!'
	RETURN
END

-- Move old data to archive table
DECLARE @BatchCount SMALLINT
DECLARE @BatchRecord INT

SELECT @BatchCount = 20, @BatchRecord = 100000

CREATE TABLE #tmpDeleted (	[custid] [int],
							[bettype] [smallint],
							[sporttype] [smallint],
							[currency] [tinyint],
							[stake] [money],
							[winlost] [money],
							[playercomm] [money],
							[odds] [money],
							[oddstype] [tinyint],
							[statusID] [tinyint],
							[recommend] [int],
							[leagueID] [int],
							[winlostdate] [smalldatetime],
							[betcount] [smallint] ,
							[isBA] [tinyint] /*,
							[awinlost] [money] ,
							[comm] [money] */)

DECLARE @iBatch TINYINT
SELECT @iBatch = @BatchCount

WHILE (@WinlostDate < @ArchiveDate AND @iBatch > 0)
BEGIN
	TRUNCATE TABLE #tmpDeleted

	DELETE TOP (@BatchRecord) 
	FROM rptCustomerTurnOver
	OUTPUT DELETED.custid, DELETED.bettype ,DELETED.sporttype, DELETED.currency, DELETED.stake,DELETED.winlost, 
			DELETED.playercomm, DELETED.odds, DELETED.oddstype,DELETED.statusID,DELETED.recommend,DELETED.leagueID,
			DELETED.winlostdate,DELETED.betcount,DELETED.isBA/*,DELETED.awinlost,DELETED.comm*/ INTO #tmpDeleted
	WHERE winlostdate = @WinlostDate

	INSERT INTO rptCustomerTurnover_bk
	SELECT * FROM #tmpDeleted

	IF (@@RowCount = 0)
	BEGIN
		SELECT @WinlostDate = MIN(Winlostdate) FROM rptCustomerTurnover (NOLOCK)
	END
	ELSE
	BEGIN
		SELECT @iBatch = @iBatch - 1
		WAITFOR DELAY '00:00:01'
	END
END

DROP TABLE #tmpDeleted