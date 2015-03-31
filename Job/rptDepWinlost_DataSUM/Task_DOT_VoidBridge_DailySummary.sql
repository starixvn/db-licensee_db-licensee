use bodb_3rdProduct
GO
/****** Object:  StoredProcedure [dbo].[Task_DOT_VoidBridge_DailySummary]    Script Date: 3/31/2015 10:26:14 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DOT_VoidBridge_DailySummary]
	@winlostdate DATETIME
AS
/*   
Created: 20140330@Winnie
Task: Summary Void Bridge data and insert into rptDepWinlost_ThirdParty
DB: DBLIC/bodb_3rdproduct
Original:
Revisions:	
Param's Explanation:
	- @winlostdate: The date need to summary
*/  
SET NOCOUNT ON
BEGIN TRY	
	DECLARE @ProductId INT
	SELECT @ProductId= ProductId FROM bodb_Licensee.dbo.Product3rd WITH(NOLOCK) WHERE ProductName='Void Bridge'
	IF(@ProductId IS NULL)
	BEGIN
	PRINT 'Error occured in Void Bridge summary data process does not exist product'
	RETURN
	END
	CREATE TABLE #TicketData (	custid			INT,								
								currency		INT,							
								turnover		MONEY,							
								winlost			MONEY,	
								drawTO			MONEY,	
								drawBetCount	INT,						
								betCount		INT)	
		INSERT INTO #TicketData (custid, currency, turnover,winlost,drawTO,drawBetCount,betCount )
		SELECT b.CustID, 		
				b.currency,				
				ISNULL(SUM(ABS([StakeAmount])),0) AS Turnover,			
				ISNULL(SUM(b.[WinAmount] - ABS(b.[StakeAmount])),0) AS Winlost,	
				0 AS DrawTO,	
				0 AS DrawBetCount,	
			ISNULL(COUNT([TransId]),0) AS Betcount			

		FROM [bodb_3rdProduct].dbo.[BetTrans_VoidBridge] b WITH (ROWLOCK)
		WHERE Winlostdate = @winlostdate AND [Status] IN ('Win','Lose')
		GROUP BY b.CustID, b.currency
	

	-- Insert data to rptDepWinlost_ThirdParty
	DELETE FROM [bodb_LicenseeReport].dbo.rptDepWinlost_ThirdParty WHERE Winlostdate = @Winlostdate and ProductId=@ProductId

	INSERT INTO [bodb_LicenseeReport].dbo.rptDepWinlost_ThirdParty (winlostdate, custid, currency, turnover,
														winlost,drawTO,drawBetCount, BetCount,ProductId)
	SELECT @winlostdate, custid,  currency, turnover,
		winlost,drawTO,drawBetCount,  BetCount, @ProductId
	FROM #TicketData

	DROP TABLE #TicketData
END TRY
BEGIN CATCH
	-- This SPs called from another SP in rptDepwinlost Summary process, failure of this SP should not affect to that process
	--RAISERROR(15000,1,1,'Error occured in summarizing AG Casino data.')
	PRINT 'Error occured in Void Bridge summary data process: ERR_CODE: '+ CAST(ERROR_NUMBER() AS VARCHAR(20)) + ', ERR_MSG: ' + ERROR_MESSAGE()
	RETURN
END CATCH