USE bodb02
GO
  
ALTER PROCEDURE dbo.Task_DailyRptLicWinloss2_Job
WITH RECOMPILE
AS  
/* Created by: Henry   
 Date: 2011-09-20  
 Task: Jobs for sum up date for rptLicWinlost  
 DB: DB052.bodb02  
  
 Revision:   
  - 20140108@Don: Add step to generate data to [bodb_LicenseeReport.rptCustomerTurnover]  
  - 20140117@Don: Add step to generate data to [bodb_LicenseeReport.rptWinlostbyleague]  
  - 20140725@Don: Add step to generate data to [bodb_LicenseeReport.rpt_BettingParlay]  
  
*/  
BEGIN  
	SET NOCOUNT ON   
	DECLARE @maxLicWinlostdate DATETIME
		, @maxSumWinlostdate DATETIME
		, @customerTurnoverWinlostdate SMALLDATETIME  
  
	SELECT  @maxLicWinlostdate = Max(Winlostdate) + 1   
	FROM bodb_Licensee.dbo.rptLicWinloss2 WITH (NOLOCK)  
     
	SELECT @maxSumWinlostdate = MAX(winlostdate)  
	FROM Sum_winloss WITH (NOLOCK)  
	WHERE Srecommend = 791080 and roleid = 4  

	DECLARE @MessageStr VARCHAR(512)
	SET @MessageStr = ''

	IF(@maxLicWinlostdate <= @maxSumWinlostdate)  
	BEGIN  
		WHILE (@maxLicWinlostdate<= @maxSumWinlostdate)
		BEGIN
			SET @MessageStr = 'WL: ' + CONVERT(VARCHAR(20), @maxLicWinlostdate, 112) + '; B WL2: ' + CONVERT(VARCHAR(50), GETDATE(), 121) + '; '
			EXEC dbo.Task_DailyRptLicWinloss2 @winlostdate = @maxLicWinlostdate
     
			SET @MessageStr = @MessageStr + 'B CTO: ' + CONVERT(VARCHAR(50), GETDATE(), 121) + '; '
  
			-- bodb_LicenseeReport.rptCustomerTurnover  
			SET @customerTurnoverWinlostdate = @maxLicWinlostdate  
			EXEC dbo.Task_rptCustomerTurnOver_Bettrans14 @Date = @customerTurnoverWinlostdate
     
			SET @MessageStr = @MessageStr + 'B L: ' + CONVERT(VARCHAR(50), GETDATE(), 121) + '; '
		   -- bodb_LicenseeReport.rptWinlostbyleague  
			EXEC dbo.Task_rptWinlostbyleague_Bettrans14 @Date = @customerTurnoverWinlostdate
     
			SET @MessageStr = @MessageStr + 'B M: ' + CONVERT(VARCHAR(50), GETDATE(), 121) + '; '
		   -- bodb_LicenseeReport.rptCustomerMatch  
			EXEC dbo.Task_rptCustomerMatch_Bettrans14 @Date = @customerTurnoverWinlostdate
     
			SET @MessageStr = @MessageStr + 'B P: ' + CONVERT(VARCHAR(50), GETDATE(), 121) + '; '
		   -- bodb_LicenseeReport.rpt_BettingParlay  
			EXEC bodb_Licensee.dbo.GEN_rptBetting_Parlay14 @datefrom = @customerTurnoverWinlostdate, @dateto = @customerTurnoverWinlostdate
			
			SET @MessageStr = @MessageStr + 'E P: ' + CONVERT(VARCHAR(50), GETDATE(), 121) + ';++ '

			PRINT @MessageStr

			SET @maxLicWinlostdate = @maxLicWinlostdate + 1   
		END    
	END
END

GO
