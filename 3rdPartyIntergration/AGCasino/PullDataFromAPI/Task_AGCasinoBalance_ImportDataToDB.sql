ALTER PROCEDURE [dbo].[Task_AGCasinoBalance_ImportDataToDB]
	@XmlData XML,	
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(500) = '' OUTPUT
AS 
/*
Created: 20150116@Winnie
Task : [[Task_AGCasinoBalance_ImportDataToDB]]
Description: Pulling AG Casino balance from API
DB: DBPTCS.bodb_PlaytechCS

Original:

Revisions:

Param explanation:

*/

SET NOCOUNT ON

DECLARE @ErrorVar INT,@RowCountVar INT

CREATE TABLE #TmpData (
	thirdpartyid	SMALLINT,
	IBCCustID		INT,
	playerName		VARCHAR(50),
	betAmount		MONEY,
	winLoss			MONEY,
	transferIn		MONEY,
	transferOut		MONEY,
	SODBalance		MONEY,
	EODBalance      MONEY,
	currency		SMALLINT,
	createdate		DATETIME
)

-- Parse XML data
BEGIN TRY


	INSERT INTO #TmpData(thirdpartyid, IBCCustID, playerName, betAmount, winLoss, transferIn, transferOut, SODBalance,EODBalance, Currency,createdate)
	SELECT 
		x.v.value('THIRDPARTYID[1]', 'SMALLINT') AS thirdpartyid,
		x.v.value('IBCCUSTID[1]', 'INT') AS IBCCustID,
		x.v.value('PLAYERNAME[1]', 'VARCHAR(50)') AS playerName,	
		x.v.value('BETAMOUNT[1]', 'MONEY') AS betAmount,	
		x.v.value('WINLOSS[1]', 'MONEY') AS winLoss,	
		x.v.value('TRANSFERIN[1]', 'MONEY') AS transferIn,	
		x.v.value('TRANSFEROUT[1]', 'MONEY') AS transferOut,
		x.v.value('SODBALANCE[1]', 'MONEY') AS SODBalance,	
		x.v.value('EODBALANCE[1]', 'MONEY') AS EODBalance,		
		x.v.value('CURRENCY[1]', 'SMALLINT') AS Currency,
		x.v.value('DATE[1]', 'DATETIME') AS createdate
	FROM    @XmlData.nodes('/TransList/TRANSACTION') x(v)
	

END TRY
BEGIN CATCH

	SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	DROP TABLE #TmpData
	RETURN
END CATCH

-- Import data to DB



	-- Insert / Update data to bettrans_AGCasino
	MERGE [dbo].[BalanceAGCasino] AS dest
	USING (	SELECT d.[Thirdpartyid], 
				d.IBCCustID, 
				e.username,
				d.playerName,
				d.betAmount, 
				d.winLoss, 
				d.transferIn, 
				d.transferOut ,			
				d.SODBalance, 
				d.EODBalance,
				d.currency,
				CONVERT(VARCHAR(10), d.createdate, 120) -- Winlostdate				
			FROM #TmpData d
				INNER JOIN bodb02.dbo.Customer e WITH(NOLOCK) ON e.custid = d.IBCCustID)				
	AS src ([Thirdpartyid], IBCCustID, UserName,playerName, betAmount, winLoss, transferInApi, transferOutApi, 
			SODBalance, EODBalance, currency, BalanceDate)
	ON (dest.CustId = src.IBCCustID AND dest.WinlostDate=src.BalanceDate)
	WHEN MATCHED THEN
		UPDATE	SET  dest.[Thirdpartyid] = src.[Thirdpartyid]
					,dest.[UserName] = src.UserName
					,dest.UserName2=src.playerName
					,dest.Stake = src.betAmount
					,dest.winLoss = src.winLoss
					,dest.transferInApi = src.transferInApi
					,dest.transferOutApi = src.transferOutApi
					,dest.[OpeningBalance] = src.SODBalance
					,dest.[ClosingBalance] = src.EODBalance
					,dest.currency = src.currency	
					,dest.ModifyDate = GETDATE()
								
	WHEN NOT MATCHED THEN
		INSERT ([Thirdpartyid], CustID, [UserName],UserName2, Stake, winLoss, transferInApi, transferOutApi, 
				[OpeningBalance], [ClosingBalance], currency, WinlostDate,createdate,[ModifyDate])
		VALUES (src.[Thirdpartyid], src.IBCCustID, src.UserName,playerName, src.betAmount, src.winLoss, src.transferInApi, src.transferOutApi, 
				src.SODBalance, src.EODBalance, src.currency, src.BalanceDate,GETDATE(),GETDATE());

	SELECT @ErrorVar=@@Error,@RowCountVar=@@ROWCOUNT	

	IF(@ErrorVar<>0) 
	BEGIN	
	SELECT @ErrCode = @ErrorVar, @ErrMsg = 'Could not import data.'	
	END

DROP TABLE #TmpData
GO

GRANT  EXECUTE  ON [dbo].[Task_AGCasinoBalance_ImportDataToDB]  TO [bodbLicenseeNet]
GO
