IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_PTCS_ImportDataToDB]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].Task_PTCS_ImportDataToDB
GO


CREATE PROCEDURE Task_PTCS_ImportDataToDB
	@XmlData XML,
	@LicenseeName VARCHAR(50),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(500) = '' OUTPUT
AS 
/*
Created: 20140410@Victor
Task : [Task_PTCS_ImportDataToDB]
DB: DBPTCS.bodb_PlaytechCS
Original:

Revisions:
	- 20140514@Victor: Change column name to PShare, PWin

Param explanation:

*/

SET NOCOUNT ON

DECLARE @NewVersionKey BIGINT

CREATE TABLE #TmpData (
	[Code] [BIGINT],
	[IBCCustID] [INT],
	[GameDate] [DATETIME],
	[SessionID] [BIGINT],
	[GameID] [INT],
	[Windowcode] [INT],
	[Name] [VARCHAR](50),
	[Bet] [MONEY],
	[Win] [MONEY],
	[JACKPOTBET] [MONEY],
	[JACKPOTWIN] [MONEY],
	[Balance] [MONEY],
	[CurrentBet] [MONEY],
	[LNName] [VARCHAR](50)
)

BEGIN TRY

SELECT @NewVersionKey = x.v.value('NewVersionKey[1]', 'BIGINT')
FROM @XmlData.nodes('/TransList') x(v)

INSERT INTO #TmpData(Code, IBCCustID, GameDate, SessionID, GameID, Windowcode, Name, Bet, Win, JACKPOTBET, JACKPOTWIN, Balance, CurrentBet, LNName)
SELECT 
	x.v.value('CODE[1]', 'BIGINT') AS Code,
	x.v.value('IBCCUSTID[1]', 'INT') AS IBCCustID,
	x.v.value('GAMEDATE[1]', 'DATETIME') AS GameDate,	
	x.v.value('SESSIONID[1]', 'BIGINT') AS SessionID,	
	x.v.value('GAMEID[1]', 'INT') AS GameID,	
	x.v.value('WINDOWCODE[1]', 'INT') AS Windowcode,	
	x.v.value('NAME[1]', 'VARCHAR(50)') AS Name,
	x.v.value('BET[1]', 'MONEY') AS Bet,	
	x.v.value('WIN[1]', 'MONEY') AS Win,
	x.v.value('JACKPOTBET[1]', 'MONEY') AS JACKPOTBET,
	x.v.value('JACKPOTWIN[1]', 'MONEY') AS JACKPOTWIN,
	x.v.value('BALANCE[1]', 'MONEY') AS Balance,
	x.v.value('CURRENTBET[1]', 'MONEY') AS CurrentBet,
	x.v.value('LNNAME[1]', 'VARCHAR(50)') AS LNName
FROM    @XmlData.nodes('/TransList/Transaction') x(v)

-- Remove tickets that are already exists in bettrans_PlaytechCS
DELETE d
FROM #TmpData d 
WHERE EXISTS (SELECT 1 FROM dbo.bettrans_PlaytechCS b (NOLOCK) WHERE b.TicketID = d.Code)

INSERT INTO dbo.bettrans_PlaytechCS(TicketID, CustID, Transdate, SessionID, GameID, Windowcode, GameName, Stake, Actual_Stake, Winlost, Status, StatusID, 
									Username, Winlostdate, ProgressiveShare, ProgressiveWin, PlaytechBalance, BrokenGameBet, LiveNetwork, 
									recommend, mrecommend, srecommend, currency)
SELECT d.Code, d.IBCCustID, d.GameDate, d.SessionID, d.GameID, d.Windowcode, d.Name, d.Bet, d.Bet, d.Win, 
	CASE 
		WHEN d.Win - d.Bet > 0 THEN 'WON'
		WHEN d.Win - d.Bet < 0 THEN 'LOSE'
		ELSE 'DRAW'
	END, -- Status
	CASE 
		WHEN d.Win - d.Bet > 0 THEN '112'
		WHEN d.Win - d.Bet < 0 THEN '113'
		ELSE '111'
	END, -- StatusID
	c.username, -- Username
	CONVERT(VARCHAR(10),d.GameDate,120), -- Winlostdate
	d.JACKPOTBET, d.JACKPOTWIN, d.Balance, d.CurrentBet, d.LNName,
	c.recommend, c.mrecommend, c.srecommend, c.currency
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

	UPDATE dbo.LicenseeVersionKey
	SET VersionKey = @NewVersionKey
	WHERE LicenseeName LIKE @LicenseeName

	IF (@@ROWCOUNT = 0)  -- Can not update NewVersionKey
	BEGIN
		SELECT @ErrCode = 1, @ErrMsg = 'Could not update New VersionKey for selected licensee. Import failed.'
		DELETE FROM dbo.bettrans_PlaytechCS WHERE TicketID IN (SELECT TicketID FROM #TmpData)
		DROP TABLE #TmpData
		RETURN
	END

END TRY 
BEGIN CATCH -- Delete data inserted on step 1
	SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	DELETE FROM dbo.bettrans_PlaytechCS WHERE TicketID IN (SELECT TicketID FROM #TmpData)
END CATCH

DROP TABLE #TmpData

GO

GRANT  EXECUTE  ON [dbo].Task_PTCS_ImportDataToDB  TO [bodbLicenseeNet]
GO