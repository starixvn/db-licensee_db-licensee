 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER PROCEDURE  [dbo].[Lrf_CurrencyCustIns]		
	@UserID INT,
	@LicenseeID INT ,	
	@Currency VARCHAR(1000),
	@ModifyBy INT,
	@Langkey VARCHAR(10) = 'en-US',
	@IP VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
	
AS	
/*
Created:20130424@Jim
Task :  Restrict permission of Licensee Users by currency
DB: DBLIC.bodb_Licensee


Revisions:
    
Param's Explanation:
@Currency: string,store the currencies assigned to Licensee Users , each CurrencyID separate  by ',' (comma)
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
DECLARE @LogSPData VARCHAR(5000)
SET @startRun = GETDATE()

CREATE TABLE #Currency (ID INT IDENTITY(1,1),CurrencyID INT )
INSERT INTO #Currency (CurrencyID)
SELECT VAL FROM bodb02.dbo.strSplit(@Currency ,',')

BEGIN
	
	DECLARE @i INT ,@maxID INT
	SELECT @i=1,@maxID=MAX(ID)
	FROM #Currency
	DELETE dbo.CurrencyUser
	WHERE usrID=@UserID
	WHILE (@i<=@maxID)
		BEGIN 
			INSERT INTO CurrencyUser(UsrID,LicenseeID,CurrencyID,SystemID,isActive)
			SELECT @UserID,@LicenseeID,CurrencyID,1,1
			FROM #Currency
			WHERE ID=@i
		
		IF (@@ERROR<>0)	
			BEGIN 
				SELECT @ErrMsg = 
						CASE @Langkey 
							WHEN 'en-US' THEN 'Update process is unsuccessful!'
							ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](90001,@Langkey)
						END, @ErrCode = 101
			END 
		SET @i=@i+1	
		END
	
	SELECT @LogSPData = '<Lrf_CurrencyCustIns LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
			'CustID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			'UserID="'+ COALESCE(CAST(@ModifyBy as VARCHAR(50)),SPACE(1)) + '" ' +
			'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
			'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
			'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
			'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'

SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)
	
EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @ModifyBy,
		@CustID = @UserID,
		@ActionID = 2801,
		@TrackingValue = @LogSPData,
		@TrackingValue2 = '',
		@duration = @duration
	
END

DROP TABLE #Currency


GO
GRANT EXECUTE ON [dbo].[Lrf_CurrencyCustIns] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CurrencyCustIns] TO [vnteam] 


