ALTER PROCEDURE [dbo].[Task_BATransaction_Loop]

AS
/*
	Created by:Jamie 
	Date:20110705
	Task: Insert BA Transaction (exec)
	DB: DB052.BODB02
	
	Revisions:
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @start DATETIME
	SELECT @start = CURRENT_TIMESTAMP

	WHILE (1=1) AND (DATEDIFF(minute,@start, CURRENT_TIMESTAMP) < 30)
	BEGIN
		EXEC [dbo].[Task_BATransaction_Ins] @TotalTicket = 10000
		WAITFOR DELAY '00:00:02'
	END

END
GO
GRANT VIEW DEFINITION ON [dbo].[Task_BATransaction_Loop] TO [vnteam]