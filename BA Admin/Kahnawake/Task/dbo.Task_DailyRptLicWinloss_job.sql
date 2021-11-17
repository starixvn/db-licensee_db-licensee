ALTER PROCEDURE [dbo].[Task_DailyRptLicWinloss_Job] 
AS
/*	Created by: Henry 
	Date: 2012-02-22
	Task: Jobs for sum up date for rptLicWinloss
	DB: bodb_MoveBet

	Revision: 
		
		

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @maxLicWinlostdate DATETIME, 
			@movebetsdate DATETIME

	SELECT  @maxLicWinlostdate=Max(Winlostdate) + 1 
	FROM	rptLicWinloss WITH (NOLOCK)

	
	SELECT	@movebetsdate = VValue
	FROM	SystemSettings WITH (NOLOCK)
	WHERE VName = 'MoveBetsDay'

	IF(@movebetsdate IS NOT NULL AND @maxLicWinlostdate <= @movebetsdate)
	BEGIN
		WHILE (@maxLicWinlostdate<= @movebetsdate)
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