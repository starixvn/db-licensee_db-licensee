ALTER PROCEDURE [dbo].[Task_DOT_GoldDeluxe_DailySummary]
	@winlostdate DATETIME
AS
/*   
Created: 20140313@Winnie
Task: Summary GoldDeluxe data and insert into rptDepWinlost_ThirdParty
DB: DBACC/bodb02
Original:
Revisions:	
Param's Explanation:
	- @winlostdate: The date need to summary
*/  
SET NOCOUNT ON
BEGIN TRY	
	DECLARE @ProductId INT
	SELECT @ProductId= ProductId FROM DBLIC.bodb_Licensee.dbo.Product3rd WITH(NOLOCK) WHERE ProductName='Gold Deluxe'
	IF(@ProductId IS NULL)
	BEGIN
	PRINT 'Error occured in AGCasino summary data process does not exist product'
	RETURN
	END
	CREATE TABLE #TicketData (	custid			INT,								
								currency		INT,							
								turnover		MONEY,							
								winlost			MONEY,								
								betCount		INT)	
		INSERT INTO #TicketData (custid, currency, turnover,winlost,betCount )
		SELECT b.CustID, 		
				b.currency,				
				ISNULL(SUM(b.Stake),0) AS Turnover,			
				ISNULL(SUM(b.Winlost - b.Stake),0) AS Winlost,			
			ISNULL(COUNT(b.TicketId),0) AS Betcount			
		FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_GoldDeluxe b WITH (ROWLOCK)
		WHERE Winlostdate = @winlostdate AND StatusId IN (111,112,113)
		GROUP BY b.CustID, b.currency
	

	-- Insert data to rptDepWinlost_ThirdParty
	DELETE FROM bodb_report.dbo.rptDepWinlost_ThirdParty WHERE Winlostdate = @Winlostdate and ProductId=@ProductId

	INSERT INTO bodb_report.dbo.rptDepWinlost_ThirdParty (winlostdate, custid, currency, turnover,
														winlost, BetCount,ProductId)
	SELECT @winlostdate, custid,  currency, turnover,
		winlost,  BetCount, @ProductId
	FROM #TicketData

	DROP TABLE #TicketData
END TRY
BEGIN CATCH
	-- This SPs called from another SP in rptDepwinlost Summary process, failure of this SP should not affect to that process
	--RAISERROR(15000,1,1,'Error occured in summarizing AG Casino data.')
	PRINT 'Error occured in AGCasino summary data process: ERR_CODE: '+ CAST(ERROR_NUMBER() AS VARCHAR(20)) + ', ERR_MSG: ' + ERROR_MESSAGE()
	RETURN
END CATCH