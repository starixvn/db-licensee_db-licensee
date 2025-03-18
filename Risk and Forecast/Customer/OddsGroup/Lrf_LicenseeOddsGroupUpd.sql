/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeOddsGroupUpd] 
	@CustID INT
	,@OddsGroup VARCHAR(10)
	,@UserID INT = 0
	,@Language varchar(2) = 'E'
	,@IP varchar(15)=''
	,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20241101@Johnson	
	Task : LAP - Update odds group for licensee 
	DB: DBCUST/CustDB
		
	Revisions:
	- 20241101@Johnson: initial sp [redmine:#199306]
	- 20250227@Virgil: Drop BA functions [RedmineID: #216882]
	
	Param's Explanation:
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()
	SET @OddsGroup = LOWER(@OddsGroup)
	
	EXEC Lrf_CustomerSelCheckAllowedDownlines
			 @custid = @CustID
			,@Language = 'E'
			,@ErrMsg = @ErrMsg OUTPUT
			,@ErrCode= @ErrCode OUTPUT

	IF @ErrCode <> 0 
		RETURN 
		
	DECLARE @IsActive_Old BIT,
		@OddsGroup_Old VARCHAR(10)
		
	SELECT @IsActive_Old = IsActive,
		@OddsGroup_Old = Ugroup
	FROM Dep_DefaultOddGroup WITH(NOLOCK)
	WHERE AgentID = @custid	
	
	MERGE Dep_DefaultOddGroup target
	USING (SELECT @custid custid) as source(custid) 
	ON (target.AgentID = source.custid)
	WHEN MATCHED THEN UPDATE SET target.ugroup = @oddsGroup,
							 target.IsActive = 1,
							 target.UserID = @UserID,
							 target.UpdatedDate = GETDATE(),
							 target.RepUpdateTime = SYSDATETIME()
	WHEN NOT MATCHED THEN INSERT(AgentID,Ugroup,UpdatedDate,UserId,IsActive,RepUpdateTime)
							VALUES(source.custid,@oddsGroup,GETDATE(),@userid,1,SYSDATETIME());
	
	CREATE TABLE #tblCust (custid INT PRIMARY KEY, isfinished BIT DEFAULT(0))
	DECLARE @ids VARCHAR(MAX), @rowcnt INT
	
	INSERT INTO #tblCust(custid)
	SELECT custid
	FROM customer WITH(NOLOCK)	
	WHERE recommend = @custid
		AND roleid = 1
		AND custid NOT IN (SELECT custid FROM [bodb_licensee].dbo.[LicenseeSpecialCust] WITH(NOLOCK))
		AND ugroup <> @oddsGroup
	
	BEGIN TRY			
		WHILE (1=1)
		BEGIN
			SELECT @ids = ''
	
			UPDATE TOP (2000) #tblCust
			SET @ids = @ids + CASE @ids WHEN '' THEN '' ELSE ',' END + CAST(custid AS VARCHAR(12))
				,isfinished = 1
			FROM #tblCust
			WHERE isfinished = 0

			SELECT @rowcnt = @@rowcount	
			
			EXEC Acc_CustomerInfo_Execrep_03 
				@CustList = @ids, 
				@oddsGroup = @oddsGroup,
				@mode = 'UpdateOddsGroup'

			IF @rowcnt < 2000 BREAK

			WAITFOR DELAY '00:00:00.28'
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrCode  = ERROR_NUMBER()   					
		RETURN
	END CATCH	
		
	DECLARE @LogSPData VARCHAR(8000),
			@LogSPData_Old VARCHAR(8000)

	SELECT  @LogSPData ='<Lrf_CustomerOddsGroupUpd OddsGroup="'+ coalesce(cast(@OddsGroup AS VARCHAR(20)),space(1))+ '" ' +
						'IsActive="'+ coalesce(cast(1 AS VARCHAR(20)),space(1))+ '" ' +
						'ApplyExistingMember="'+ coalesce(cast(1 AS VARCHAR(50)),space(1))+ '" ' +						
						'Language="'+ coalesce(cast(@Language as varchar(2)),space(1))+ '" ' +
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+ '" ' +
						'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
						'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'
	
	SELECT  @LogSPData_Old ='<Lrf_CustomerOddsGroupUpd OddsGroup="'+ coalesce(cast(ISNULL(@OddsGroup_Old,'') AS VARCHAR(20)),space(1))+ '" ' +
						'IsActive="'+ coalesce(cast(ISNULL(@IsActive_old,0) AS VARCHAR(20)),space(1))+ '" ' +
						'ApplyExistingMember="'+ coalesce(cast(1 AS VARCHAR(50)),space(1))+ '" ' +						
						'Language="'+ coalesce(cast(@Language as varchar(2)),space(1))+ '" ' +
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+ '" ' +
						'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
						'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'
	
	
	set @endRun = getdate()
	set @duration  = datediff (millisecond,@startRun,@endRun)

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 2222,
			@TrackingValue		= @LogSPData,
			@TrackingValue2		= @LogSPData_Old,
			@Duration			= @Duration
END	