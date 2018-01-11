USE [CustDB]
GO

ALTER PROCEDURE [dbo].[NAP_LM_LicenseeBetSettingUpd_Manual] 
	@CustID INT
	,@Sporttype INT
	,@Bettype INT = 0
	,@MinBet MONEY
	,@MaxBet MONEY
	,@MaxPerMatch MONEY
	,@MaxPerBall MONEY = 0
	,@ExistedMember BIT
	,@Enable BIT = 0
	,@EnableDownline BIT = 0
	,@UserID INT = 0
	,@Language varchar(2) = 'E'
	,@IP VARCHAR(15)=''
	,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20150108
	Task : Licensee Setting Configuration - Update Bet Setting [#6304]
	DB: DBCUST/CustDB
	Original:

	Revisions:
	   - 20150630@Daniel: Migrate custDB to new server DBCus [Redmine:#36216] - Separate exec sp	update cust info

	Param's Explanation:
	Example:	DECLARE @ErrCode INT = 0, @ErrMsg NVARCHAR(4000) = ''
																																EXEC NAP_LM_LicenseeBetSettingUpd @CustID = 16947245, @Sporttype = 151, @Bettype = 31, @MinBet = 25, @MaxBet = 205, @MaxPerMatch = 2005, @ExistedMember = 1, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
				SELECT @ErrCode, @ErrMsg
		
*/ 
BEGIN
 SET NOCOUNT ON
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = getdate()
	SELECT @ErrCode = 0, @ErrMsg =''	
	
	CREATE TABLE #temp(custid INT PRIMARY KEY, isfinished BIT DEFAULT(0))
	INSERT INTO #temp(custid)
	SELECT custid
	FROM custinfo WITH(NOLOCK)	
	WHERE srecommend = @CustID
			AND mrecommend NOT IN (SELECT custid FROM custinfo WITH(NOLOCK)
									WHERE srecommend = @CustID AND username LIKE '%Acc%' AND roleid=3)
	BEGIN TRY
		DECLARE @ids VARCHAR(MAX), @rowcnt INT
		WHILE (1=1)
		BEGIN
			SELECT @ids = ''
	
			UPDATE TOP (10000) #temp
			SET @ids = @ids + CASE @ids WHEN '' THEN '' ELSE ',' END + CAST(custid AS VARCHAR(12))
				,isfinished = 1
			FROM #temp
			WHERE isfinished = 0

			SELECT @rowcnt = @@rowcount	
		  
			 --add update cust info exec rep
			 			 			 			 EXEC [dbo].[Acc_CustomerInfo_Execrep_07]
				 @ids = @ids
				 ,@Sporttype = @Sporttype
				 ,@Bettype = @Bettype
				 ,@MaxPerMatch = @MaxPerMatch
				 ,@MaxPerBall = @MaxPerBall
				 ,@ExistedMember = @ExistedMember
				 ,@Enable = @Enable
				 ,@EnableDownline = @EnableDownline
				 
												EXEC Acc_CustSetting3rd_11 
				@ids = @ids, 
				@srecommend = @CustID, 
				@Sporttype = @Sporttype, 
				@Bettype = @Bettype, 
				@MinBet = @MinBet, 
				@MaxBet = @MaxBet, 
				@MaxPerMatch = @MaxPerMatch, 
				@ExistedMember = @ExistedMember, 
				@Enable = @Enable, 
				@EnableDownline = @EnableDownline

			IF @rowcnt < 10000 BREAK

			WAITFOR DELAY '00:00:00.28'
		END		
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrCode  = ERROR_NUMBER()   					
		RETURN
	END CATCH

	DECLARE @LogSPData VARCHAR(8000)

	SELECT  @LogSPData ='<NAP_LM_LicenseeBetSettingUpd custid="'+ coalesce(cast(@CustID AS VARCHAR(20)),space(1))+ '" ' +
						'Sporttype="'+ coalesce(cast(@Sporttype AS VARCHAR(20)),space(1))+ '" ' +
						'Bettype="'+ coalesce(cast(@Bettype AS VARCHAR(20)),space(1))+ '" ' +
						'MinBet="'+ coalesce(cast(@MinBet AS VARCHAR(50)),space(1))+ '" ' +
						'MaxBet="'+ coalesce(cast(@MaxBet AS VARCHAR(50)),space(1))+ '" ' +
						'MaxPerMatch="'+ coalesce(cast(@MaxPerMatch AS VARCHAR(50)),space(1))+ '" ' +
						'MaxPerBall="'+ coalesce(cast(@MaxPerBall AS VARCHAR(50)),space(1))+ '" ' +
						'ApplyMember="'+ coalesce(cast(@ExistedMember AS VARCHAR(1)),space(1))+ '" ' +
						'Enable="'+ coalesce(cast(@Enable AS VARCHAR(1)),space(1))+ '" ' +
						'EnableDownline="'+ coalesce(cast(@EnableDownline AS VARCHAR(1)),space(1))+ '" ' +
						'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1))+ '" ' +
						'Language="'+ coalesce(cast(@Language as varchar(2)),space(1))+ '" ' +
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+ '" ' +
						'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
						'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'

	set @endRun = getdate()
	set @duration  = datediff (millisecond,@startRun,@endRun)

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@UserID = @UserID,
			@CustID = @CustID,
			@ActionID = 2043, 
			@TrackingValue = @LogSPData,
			@duration = @duration
	END TRY
	BEGIN CATCH
		SELECT  @LogSPData ='<NAP_LM_LicenseeBetSettingUpd custid="'+ coalesce(cast(@CustID AS VARCHAR(20)),space(1))+ '" ' +
						'Sporttype="'+ coalesce(cast(@Sporttype AS VARCHAR(20)),space(1))+ '" ' +
						'Bettype="'+ coalesce(cast(@Bettype AS VARCHAR(20)),space(1))+ '" ' +
						'MinBet="'+ coalesce(cast(@MinBet AS VARCHAR(50)),space(1))+ '" ' +
						'MaxBet="'+ coalesce(cast(@MaxBet AS VARCHAR(50)),space(1))+ '" ' +
						'MaxPerMatch="'+ coalesce(cast(@MaxPerMatch AS VARCHAR(50)),space(1))+ '" ' +
						'MaxPerBall="'+ coalesce(cast(@MaxPerBall AS VARCHAR(50)),space(1))+ '" ' +
						'ApplyMember="'+ coalesce(cast(@ExistedMember AS VARCHAR(1)),space(1))+ '" ' +
						'Enable="'+ coalesce(cast(@Enable AS VARCHAR(1)),space(1))+ '" ' +
						'EnableDownline="'+ coalesce(cast(@EnableDownline AS VARCHAR(1)),space(1))+ '" ' +
						'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1))+ '" ' +
						'Language="'+ coalesce(cast(@Language as varchar(2)),space(1))+ '" ' +
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+ '" ' +
						'ErrCode="' + coalesce(cast(ERROR_NUMBER() as varchar(50)),space(1)) + 
						'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1)) + '" />'
					
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@UserID = @UserID,
			@CustID = @CustID,
			@ActionID = 2043, 
			@TrackingValue = @LogSPData,
			@duration = @duration	
	END CATCH		
END

GO
GRANT VIEW DEFINITION ON dbo.NAP_LM_LicenseeBetSettingUpd_Manual TO vnteam