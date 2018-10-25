/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
USE bodb_Licensee
GO

ALTER PROCEDURE  [dbo].[Lrf_CurrencyCustIns]		
	@UserID INT,
	@LicenseeID INT ,	
	@CurrencyXML VARCHAR(max),
	@ModifyBy INT,
	@Langkey VARCHAR(10) = 'en-US',
	@IP VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT	
AS	
/*
	Created:20130424@Jim
	Task : Restrict permission of Licensee Users by currency
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
    
	Param's Explanation:
		@Currency: string,store the currencies assigned to Licensee Users , each CurrencyID separate  by ',' (comma)
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	DECLARE @LogSPData VARCHAR(5000)
	DECLARE @LogSPData2 VARCHAR(5000)
	SET @startRun = GETDATE()
	DECLARE @iDoc INT , @i INT, @max INT 

	CREATE TABLE  #Currency (ID INT IDENTITY(1,1),currencyid INT, status INT)
	EXEC sp_xml_preparedocument @iDoc OUTPUT,@CurrencyXML

	INSERT INTO #Currency (CurrencyID,status)
	SELECT CurrencyID,status
	FROM 
		OPENXML(@iDoc,'/currencies/currency',0)
	WITH (currencyid varchar(20),status varchar(10))
	
	SELECT @i=1,@max=MAX(ID) FROM #currency 
	SET @LogSPData2=''
	WHILE (@i<=@max)
	BEGIN 
		
		SELECT @LogSPData2=@LogSPData2+','+CONVERT(VARCHAR(10),CurrencyID) 
		FROM #Currency 
		WHERE ID=@i
		AND status=1
		SET @i=@i+1	
	END

	BEGIN
		DELETE dbo.CurrencyUser WHERE usrID=@UserID AND LicenseeID=@LicenseeID
	
		INSERT INTO dbo.CurrencyUser
		SELECT @UserID,@LicenseeID,CurrencyID,1,status
		FROM #Currency
		/*
		UPDATE dbo.CurrencyUser WITH (ROWLOCK,UPDLOCK)
		SET isActive=s.status
		FROM dbo.CurrencyUser d
			INNER JOIN #Currency s ON d.CurrencyID=s.CurrencyID AND d.usrID=@UserID AND d.LicenseeID=@LicenseeID 
		*/	
		-------------------------------------
		DROP TABLE #Currency
		exec sp_xml_removedocument @iDoc		
		-------------------------------------
		IF (@@ERROR<>0)	
		BEGIN 
			SELECT @ErrMsg = 
					CASE @Langkey 
						WHEN 'en-US' THEN 'Update process is unsuccessful!'
						ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](90001,@Langkey)
					END, @ErrCode = 101
		END 

		SELECT @LogSPData = '<Lrf_CurrencyCustIns LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
				'CustID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
				'UserID="'+ COALESCE(CAST(@ModifyBy as VARCHAR(50)),SPACE(1)) + '" ' +
				'CurrencyID="'+ COALESCE(CAST(@LogSPData2  as VARCHAR(500)),SPACE(1)) + '" ' +
				'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
				'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
				'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
				'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'

		SET @endRun = GETDATE()
		SET @duration  = datediff (millisecond,@startRun,@endRun)

		EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @ModifyBy,
			@CustID = @UserID,
			@ActionID = 2801,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = '',
			@duration = @duration
	END
END
GO

