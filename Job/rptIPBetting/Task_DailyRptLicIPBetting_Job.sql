ALTER PROCEDURE [dbo].[Task_DailyRptLicIPBetting_Job] 
AS
/*	Created by: Henry 
	Date: 2012-05-30
	Task: Jobs for sum up for rptLicIPBetting
	DB: DB052.bodb02

	Revision: 
		
		

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @DATA AS  TABLE (id INT  IDENTITY,winlostdate SMALLDATETIME)
	DECLARE @winlostdate SMALLDATETIME
	
	INSERT INTO @DATA (winlostdate)
	SELECT DISTINCT winlostdate FROM bettrans14 (NOLOCK)
	
	DECLARE @i INT, @MAX INT
	SET @i = 0

	SELECT @MAX = MAX(id) FROM @DATA
	
	WHILE @i < @MAX
	BEGIN
		SET @i = @i + 1
		SELECT @winlostdate = winlostdate FROM @DATA WHERE id = @i
		
		EXEC [Task_DailyRptLicIPBetting] @winlostdate = @winlostdate
	END
	
END  
	

GO 
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptLicIPBetting_Job] TO [VNTeam]
GO   