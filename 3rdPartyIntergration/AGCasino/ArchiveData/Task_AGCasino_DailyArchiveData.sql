IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_AGCasino_DailyArchiveData]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].Task_AGCasino_DailyArchiveData
GO


CREATE PROCEDURE Task_AGCasino_DailyArchiveData
AS 
/*
Created: 20140916@Victor
Task : [Task_AGCasino_DailyArchiveData]
Description: Archive AG Casino data daily
DB: DBACC/bodb02
Original:

Revisions:

Param explanation:

*/
BEGIN
	SET NOCOUNT ON
	DECLARE @winlostdate SMALLDATETIME, @todate SMALLDATETIME
	SELECT @todate = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP)-14, 0)
	SELECT @winlostdate = MIN(winlostdate) FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_AGCasino WITH (NOLOCK)

	DECLARE @ErrCode INT
	WHILE (@winlostdate < @todate)
	BEGIN
		-- Archive AG Casino data
		INSERT INTO bodb_archive.dbo.bettrans_AGCasino_bk (	TicketID, CustID, Transdate, GameType, Stake, Actual_Stake,
															Winlost, [Status], StatusID, PlayType, Winlostdate, Username,
															IP, recommend, mrecommend, srecommend, Currency, IsVIPGame)
		SELECT	TicketID, CustID, Transdate, GameType, Stake, Actual_Stake,
				Winlost, [Status], StatusID, PlayType, Winlostdate, Username,
				IP, recommend, mrecommend, srecommend, Currency, IsVIPGame
		FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_AGCasino WITH (NOLOCK)
		WHERE Winlostdate = @winlostdate

		IF (@@ERROR <> 0)
		BEGIN
			PRINT 'Error occurred when archiving data. @Winlostdate = ' + CONVERT(VARCHAR(10), @Winlostdate, 120)
			RETURN
		END

		-- Delete old data
		DELETE FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_AGCasino WITH (ROWLOCK) WHERE Winlostdate = @winlostdate
		SELECT @winlostdate = DATEADD(dd, 1, @winlostdate)
		
		IF (@@ERROR <> 0)
		BEGIN
			PRINT 'Error occurred when deleting old data. @Winlostdate = ' + CONVERT(VARCHAR(10), @Winlostdate, 120)
			DELETE FROM bodb_archive.dbo.bettrans_AGCasino_bk WHERE Winlostdate = @Winlostdate
			RETURN
		END

	END
END
GO