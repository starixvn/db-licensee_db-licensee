/*<info serverAlias="DBLog-bodb_CustomerLog" executers="bodbLicenseeNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Lrf_WriteLog_UserLog_UserControl_Multiple]
	@LogData NVARCHAR(MAX),	
	@TypeID tinyint=0,
	@ActionID int=0,
	@Duration int = 0,
	@UserID	INT 
AS
/*
	Created: 20221109@Johnson
	Task : Write multiple log for LAP when update settings
	DB: DBLog/bodb_CustomerLog

	Revisions :
		- 20221109@Johnson: initial sp [redmine:#179961]
	
	Parameter Explanation:
		@ActionID = 5567--Deactive VIP
		@LogData = '<Root>
						<r id="1" log="LAP - 12Bet - 1 - 5 - Success - OFF - ON" />
						<r id="2" log="LAP - 12Bet - 1 - 5 - Success - OFF - ON" />
					</Root>'
		id: custid, log: log update		
*/
BEGIN
	SET NOCOUNT ON
	
	IF @ActionID = 5567 --Deactive VIP
	BEGIN
		CREATE TABLE #tblLogVIP (custid INT PRIMARY KEY, log NVARCHAR(MAX))
		DECLARE @xmlLogVIP XML = CAST(@LogData as XML)
		
		INSERT INTO #tblLogVIP(custid,log)	
		SELECT t.c.value('@id','INT')	AS custid		
			,t.c.value('@log', 'NVARCHAR(MAX)')	AS log			
		FROM @xmlLogVIP.nodes ('Root/r') t(c)
		OPTION (OPTIMIZE FOR (@xmlLogVIP = NULL))
				
		INSERT INTO  dbo.UserLog_UserControl
			   ([CustID]
			   ,[LogDate]
			   ,[UserID]
			   ,[TypeID]
			   ,[ActionID]
			   ,[Duration]
			   ,[Doing])
		SELECT custid, 
			GETDATE(),
			@UserID,
			@TypeID,
			@ActionID,
			@Duration,
			log
		FROM #tblLogVIP
		
		DROP TABLE #tblLogVIP
	END	
END			
GO