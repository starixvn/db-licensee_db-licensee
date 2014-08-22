ALTER PROCEDURE [dbo].[Task_DailyRptLicWinloss2_Job] 
AS
/*	Created by: Henry 
	Date: 2011-09-20
	Task: Jobs for sum up date for rptLicWinlost
	DB: DB052.bodb02

	Revision: 
		- 20140108@Don: Add step to generate data to [bodb_LicenseeReport.rptCustomerTurnover]
		- 20140117@Don: Add step to generate data to [bodb_LicenseeReport.rptWinlostbyleague]
		
		

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @maxLicWinlostdate DATETIME, 
			@maxSumWinlostdate DATETIME,
			@customerTurnoverWinlostdate SMALLDATETIME

	SELECT  @maxLicWinlostdate=Max(Winlostdate) + 1 
	FROM	bodb_Licensee.dbo.rptLicWinloss2 WITH (NOLOCK)

	
	SELECT	@maxSumWinlostdate = MAX(winlostdate)
	FROM	Sum_winloss WITH (NOLOCK)
	WHERE	Srecommend = 791080 and roleid = 4

	IF(@maxLicWinlostdate <= @maxSumWinlostdate)
	BEGIN
		WHILE (@maxLicWinlostdate<= @maxSumWinlostdate)
		BEGIN
			PRINT @maxLicWinlostdate
			EXEC dbo.Task_DailyRptLicWinloss2 @winlostdate = @maxLicWinlostdate
			
			-- bodb_LicenseeReport.rptCustomerTurnover
			SET @customerTurnoverWinlostdate = @maxLicWinlostdate
			EXEC dbo.Task_rptCustomerTurnOver_Bettrans14 @Date = @customerTurnoverWinlostdate
			
			-- bodb_LicenseeReport.rptWinlostbyleague
			EXEC dbo.Task_rptWinlostbyleague_Bettrans14 @Date = @customerTurnoverWinlostdate
			
			SET @maxLicWinlostdate = @maxLicWinlostdate + 1 
		END		

	END
	
	
END  
	



GO
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptLicWinloss2_Job] TO [vnteam] AS [dbo]