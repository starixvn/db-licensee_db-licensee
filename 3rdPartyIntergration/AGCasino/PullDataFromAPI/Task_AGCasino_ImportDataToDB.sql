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
	- 20141017@Victor: remove time convertion, input data have GMT -4 timezone already

Param explanation:

*/

SET NOCOUNT ON

DECLARE @NewVersionKey BIGINT, @OldVersionKey BIGINT

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

-- Parse XML data
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
	
	SELECT @OldVersionKey = SettingValue
	FROM dbo.LicIntegrationSetting 
	WHERE LicenseeName LIKE @LicenseeName
		AND SettingName LIKE 'AGCasino_VersionKey'
END TRY
BEGIN CATCH
	SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	DROP TABLE #TmpData
	RETURN
END CATCH

-- Import data to DB
BEGIN TRY
	-- Update VersionKey value
	UPDATE dbo.LicIntegrationSetting WITH (ROWLOCK, UPDLOCK)
	SET SettingValue = @NewVersionKey
	WHERE LicenseeName LIKE @LicenseeName
		AND SettingName LIKE 'AGCasino_VersionKey'

	IF (@@ROWCOUNT = 0)  -- Can not update NewVersionKey
	BEGIN
		SELECT @ErrCode = 1, @ErrMsg = 'Could not update New VersionKey for selected licensee. Import failed.'
		DROP TABLE #TmpData
		RETURN
	END

	-- Insert / Update data to bettrans_AGCasino
	MERGE dbo.bettrans_AGCasino AS dest
	USING (	SELECT d.BillNo, 
				d.IBCCustID, 
				d.BetTime,
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
				CONVERT(VARCHAR(10), d.BetTime, 120), -- Winlostdate
				c.username, -- Username
				d.LoginIP, -- IP
				c.recommend, c.mrecommend, c.srecommend, c.currency,
				CASE WHEN GameType LIKE 'CBAC' THEN 1 ELSE 0 END -- IsVIPGame
			FROM #TmpData d
				INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = d.IBCCustID)
	AS src (BillNo, IBCCustID, Transdate, GameType, Stake, Actual_Stake, Winlost, [Status], StatusID, 
			PlayType, Winlostdate, Username, LoginIP, recommend, mrecommend, srecommend, currency, IsVIPGame)
	ON (dest.TicketID = src.BillNo)
	WHEN MATCHED THEN
		UPDATE	SET dest.CustID = src.IBCCustID
					,dest.Transdate = src.Transdate
					,dest.GameType = src.GameType
					,dest.Stake = src.Stake
					,dest.Actual_Stake = src.Actual_Stake
					,dest.Winlost = src.Winlost
					,dest.[Status] = src.[Status]
					,dest.StatusID = src.StatusID
					,dest.PlayType = src.PlayType
					,dest.Winlostdate = src.Winlostdate
					,dest.Username = src.Username
					,dest.IP = src.LoginIP
					,dest.recommend = src.recommend
					,dest.mrecommend = src.mrecommend
					,dest.srecommend = src.srecommend
					,dest.currency = src.currency
					,dest.IsVIPGame = src.IsVIPGame
	WHEN NOT MATCHED THEN
		INSERT (TicketID, CustID, Transdate, GameType, Stake, Actual_Stake, Winlost, 
				[Status], StatusID, PlayType, Winlostdate,  Username, IP, 
				recommend, mrecommend, srecommend, Currency, IsVIPGame)
		VALUES (src.BillNo, src.IBCCustID, src.Transdate, src.GameType, src.Stake, src.Actual_Stake, src.Winlost, 
				src.[Status], src.StatusID, src.PlayType, src.Winlostdate, src.Username, src.LoginIP, 
				src.recommend, src.mrecommend, src.srecommend, src.currency, src.IsVIPGame);
	
END TRY 
BEGIN CATCH
	SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

	-- Update VersionKey value to old value
	UPDATE dbo.LicIntegrationSetting WITH (ROWLOCK, UPDLOCK)
	SET SettingValue = @OldVersionKey
	WHERE LicenseeName LIKE @LicenseeName
		AND SettingName LIKE 'AGCasino_VersionKey'
END CATCH

DROP TABLE #TmpData

GO

GRANT  EXECUTE  ON [dbo].Task_AGCasino_ImportDataToDB  TO [bodbLicenseeNet]
GO