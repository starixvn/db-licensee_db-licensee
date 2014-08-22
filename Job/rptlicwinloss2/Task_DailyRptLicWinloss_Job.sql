ALTER PROCEDURE [dbo].[Task_DailyRptLicWinloss_Job] 
AS
/*	Created by: Henry 
	Date: 2011-09-20
	Task: Jobs for sum up date for rptLicWinlost
	DB: DB052.bodb02

	Revision: 
		
		

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @maxLicWinlostdate DATETIME, 
			@maxSumWinlostdate DATETIME

	SELECT  @maxLicWinlostdate=Max(Winlostdate) + 1 
	FROM	bodb_Licensee.dbo.rptLicWinloss WITH (NOLOCK)

	
	SELECT	@maxSumWinlostdate = MAX(winlostdate)
	FROM	Sum_winloss WITH (NOLOCK)
	WHERE	Srecommend = 791080 and roleid = 4

	IF(@maxLicWinlostdate <= @maxSumWinlostdate)
	BEGIN
		WHILE (@maxLicWinlostdate<= @maxSumWinlostdate)
		BEGIN
			PRINT @maxLicWinlostdate
			EXEC dbo.Task_DailyRptLicWinloss @winlostdate = @maxLicWinlostdate
			SET @maxLicWinlostdate = @maxLicWinlostdate + 1 
		END		

	END
	
	
END  
	

GO 
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptLicWinloss_Job] TO [VNTeam]
GO   