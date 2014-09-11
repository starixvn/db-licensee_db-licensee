IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_AGCasino_ImportDataToDB]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].Task_AGCasino_ImportDataToDB
GO


CREATE PROCEDURE Task_AGCasino_ImportDataToDB
	@XmlData XML,
	@LicenseeName VARCHAR(50),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(500) = '' OUTPUT
AS 
/*
Created: 20140909@Victor
Task : [Task_AGCasino_ImportDataToDB]
Description: Pulling AG Casino bet tickets from API
DB: DBPTCS.bodb_PlaytechCS

Original:

Revisions:

Param explanation:

*/

SET NOCOUNT ON

DECLARE @NewVersionKey BIGINT

CREATE TABLE #TmpData (
	BillNo		BIGINT,
	IBCCustID	INT,
	BetTime		DATETIME,
	GameType	VARCHAR(10),
	BetAmount	MONEY,
	NetAmount	MONEY,
	PlayType	SMALLINT,
	LoginIP		VARCHAR(20),
	Currency	TINYINT,
)

BEGIN TRY

SELECT @NewVersionKey = x.v.value('NEWVERSIONKEY[1]', 'BIGINT')
FROM @XmlData.nodes('/TransList') x(v)

INSERT INTO #TmpData(BillNo, IBCCustID, BetTime, GameType, BetAmount, NetAmount, PlayType, LoginIP, Currency)
SELECT 
	x.v.value('BILLNO[1]', 'BIGINT') AS BillNo,
	x.v.value('IBCCUSTID[1]', 'INT') AS IBCCustID,
	x.v.value('BETTIME[1]', 'DATETIME') AS BetTime,	
	x.v.value('GAMETYPE[1]', 'VARCHAR(10)') AS GameType,	
	x.v.value('BETAMOUNT[1]', 'MONEY') AS BetAmount,	
	x.v.value('NETAMOUNT[1]', 'MONEY') AS NetAmount,	
	x.v.value('PLAYTYPE[1]', 'SMALLINT') AS PlayType,
	x.v.value('LOGINIP[1]', 'VARCHAR(20)') AS LoginIP,	
	x.v.value('CURRENCY[1]', 'TINYINT') AS Currency
FROM    @XmlData.nodes('/TransList/TRANSACTION') x(v)

-- Remove tickets that are already exists in bettrans_AGCasino
DELETE d
FROM #TmpData d 
WHERE EXISTS (SELECT 1 FROM dbo.bettrans_AGCasino b (NOLOCK) WHERE b.TicketID = d.BillNo)

INSERT INTO dbo.bettrans_AGCasino(	TicketID, CustID, Transdate, GameType, Stake, Actual_Stake, 
									Winlost, [Status], StatusID, PlayType, Winlostdate,  Username, 
									IP, recommend, mrecommend, srecommend, Currency, IsVIPGame)
SELECT d.BillNo, 
	d.IBCCustID, 
	DATEADD(HOUR, -12, d.BetTime), -- Convert time from GMT+8 to GMT-4
	d.GameType, -- GameType
	d.betAmount, -- Stake
	d.betAmount, -- Actual_Stake
	d.betAmount + d.NetAmount, -- Winlost 
	CASE 
		WHEN d.NetAmount > 0 THEN 'WON'
		WHEN d.NetAmount < 0 THEN 'LOSE'
		ELSE 'DRAW'
	END, -- Status
	CASE 
		WHEN d.NetAmount > 0 THEN '112'
		WHEN d.NetAmount < 0 THEN '113'
		ELSE '111'
	END, -- StatusID
	d.PlayType, -- PlayType
	CONVERT(VARCHAR(10),DATEADD(HOUR, -12, d.BetTime),120), -- Winlostdate
	c.username, -- Username
	d.LoginIP, -- IP
	c.recommend, c.mrecommend, c.srecommend, c.currency,
	CASE WHEN GameType LIKE 'CBAC' THEN 1 ELSE 0 END -- IsVIPGame
FROM #TmpData d
	INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = d.IBCCustID
END TRY
BEGIN CATCH
	SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	DROP TABLE #TmpData
	RETURN
END CATCH

-- Update VersionKey value
BEGIN TRY

	UPDATE dbo.LicIntegrationSetting
	SET SettingValue = @NewVersionKey
	WHERE LicenseeName LIKE @LicenseeName
		AND SettingName LIKE 'AGCasino_VersionKey'

	IF (@@ROWCOUNT = 0)  -- Can not update NewVersionKey
	BEGIN
		SELECT @ErrCode = 1, @ErrMsg = 'Could not update New VersionKey for selected licensee. Import failed.'
		DELETE FROM dbo.bettrans_AGCasino WHERE TicketID IN (SELECT TicketID FROM #TmpData)
		DROP TABLE #TmpData
		RETURN
	END

END TRY 
BEGIN CATCH -- Delete data inserted on step 1
	SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	DELETE FROM dbo.bettrans_AGCasino WHERE TicketID IN (SELECT TicketID FROM #TmpData)
END CATCH

DROP TABLE #TmpData

GO

GRANT  EXECUTE  ON [dbo].Task_AGCasino_ImportDataToDB  TO [bodbLicenseeNet]
GO