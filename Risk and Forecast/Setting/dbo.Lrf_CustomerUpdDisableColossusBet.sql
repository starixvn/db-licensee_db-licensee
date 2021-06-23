/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdDisableColossusBet] 
	  @CustID			INT
	, @Disabled	VARCHAR(MAX)	
	, @UserID			INT
	, @IP				VARCHAR(50)		= ''	
	, @ErrCode			INT				= 0		OUTPUT	
	, @ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20210622@Johnson
	Task : update status for ColossusBet
	DB: DBCUST/CustDB
	Original:

	Revisions:
		- 20210622@Johnson: initial sp [redmine:#156680]
	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun			DATETIME
			,@endRun			DATETIME
			,@duration			INT			
			,@Disabled_Old		BIT			= 0
			,@roleid 			TINYINT
	SET @startRun = GETDATE()
	
	--Check disable user  
	EXEC dbo.Acc_CustomerSelCheckEnable @custid = @custid  
		,@ErrCode = @ErrCode OUTPUT  
		,@ErrMsg = @ErrMsg OUTPUT  

	IF @ErrCode > 0  
		RETURN  
	
	-- Get old status of member
	DECLARE @Srecommend INT
			,@SDisabled INT = 0
	SELECT @Srecommend = srecommend FROM dbo.Customer c WITH (NOLOCK) WHERE c.CustID = @CustID

	SELECT @Disabled_Old = DisableColossusBet,
		@Srecommend = srecommend,
		@roleid = roleid
	FROM custInfo WITH(NOLOCK)  
	WHERE custid = @custid
		AND srecommend IN (SELECT custid FROM Dep_CustSuper WITH(NOLOCK))
	
	IF (@RoleID NOT IN (1, 2, 3, 4))  
	BEGIN  
		SELECT @ErrMsg = 'Invalid user!'  						
			, @ErrCode = 100  

		RETURN  
	END  
	
	SELECT @SDisabled = DisableColossusBet
	FROM custInfo WITH(NOLOCK)  
	WHERE custid = @Srecommend

	IF (@SDisabled = 1)
		SELECT @Disabled_Old = 1
	
	IF @Disabled = @Disabled_Old
		RETURN;
	
	UPDATE dbo.CustInfo WITH(ROWLOCK, UPDLOCK)  
		SET DisableColossusBet = @Disabled,  
			HideColossusBet = CASE WHEN HideColossusBet = 1 THEN 0 ELSE HideColossusBet END    
	WHERE custid = @CustID  
	
	DECLARE @LogSPData VARCHAR(MAX),    
			@LogSPData_Old VARCHAR(2000)    
	 
	SELECT @LogSPData = '<Lrf_CustomerUpdDisableColossusBet CustID="'+ coalesce(cast(@CustID as varchar(50)),space(1)) + '" '+    
		'Disable="'+ coalesce(cast(@Disabled as varchar(50)),space(1)) + '" '+    		
		'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" '+    
		'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '+    
		'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(400)),space(1))+'" '+    
		'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+'" />'    

	SELECT @LogSPData_Old = '<Lrf_CustomerUpdDisableColossusBet CustID="'+ coalesce(cast(@CustID as varchar(50)),space(1)) + '" '+    
		'Disable="'+ coalesce(cast(@Disabled_old as varchar(50)),space(1)) + '" '+    
		'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" '+    
		'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '+    
		'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(400)),space(1))+'" '+    
		'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+'" />'    
	  
	SET @endRun = GETDATE()    
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)    
	
	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @UserID,
			@CustID = @CustID,
			@ActionID = 2217,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @LogSPData_Old,
			@duration = @duration		
END	
GO