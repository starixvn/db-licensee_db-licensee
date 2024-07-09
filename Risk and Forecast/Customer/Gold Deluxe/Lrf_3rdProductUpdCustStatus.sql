/*<info serverAlias="DBCUST-CustDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	[dbo].[Lrf_3rdProductUpdCustStatus]  
	@CustID		INT,
	@ProductId	INT,
	@IsEnabled	BIT,
	@UserID		INT, 
	@IP			VARCHAR(40),
	@Language	VARCHAR(10)		= 'en-US',	
	@ErrMsg		VARCHAR(100)	= ''	OUTPUT 
AS
/*
	Created: 20150304@Winnie
	Task: Update status of 3rd product(Gold Dexluxe...) for Members
	DB: DBCUST.CustDB
	Original:
	Revisions:
		-20150609@Jim: support product microgaming
		-20151022@Jim: support #44780
		-20151108@Jim: Separated MicroGaming into 2 product
		-20160909@Winnie: support colossusBet RedmineID: #63785
		-20190321@Winnie: LAP-Remove MGC & Korea Language RedmineID: #107704
		-20210823@Johnson: update status for RnG Keno[redmineID:#159696]
		-20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898]
		- 20230615@Tacy: Remove columns and code used by Colossus Bets, GD product [RedmineID: #188096]
		- 20240715@Johnson: Apply In-house Replication for Customer Setting [redmine:#207025]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @startRun			DATETIME
			,@endRun			DATETIME
			,@duration			INT
			,@LogSPData			VARCHAR(MAX)
			,@TrackingValue2	VARCHAR(MAX)
			,@IsEnable_Old		BIT			= 0
	SET @startRun = GETDATE()

	-- Get old status of member
	DECLARE @Srecommend INT
			,@SEnabled INT = 0
	SELECT @Srecommend = srecommend FROM dbo.Customer c WITH (NOLOCK) WHERE c.CustID = @CustID
	
	SELECT @IsEnable_Old = ISNULL(IsEnabled,0)
	FROM dbo.Dep_CustProductSetting WITH (NOLOCK)
	WHERE CustID = @CustId AND ProductId=@ProductId

	SELECT @SEnabled = ISNULL(IsEnabled,0) FROM dbo.Dep_SupperProductSetting WITH (NOLOCK) WHERE CustID = @Srecommend AND ProductId=@ProductId
		
	IF (@SEnabled = 0)
		SELECT @IsEnable_Old = 0

	-- Call SP to update status
	DECLARE @CustIDs VARCHAR(20)
	SELECT @CustIDs = CONVERT(VARCHAR(20), @CustID)


	CREATE TABLE #CustList (CustID INT)

	INSERT INTO #CustList (CustID)
	SELECT value FROM STRING_SPLIT(@CustIDs,',') WHERE value <> ''
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not update'
	RETURN
	END

	UPDATE dbo.Dep_CustProductSetting WITH (ROWLOCK, UPDLOCK)
	SET IsEnabled = @IsEnabled,
		RepUpdateTime = SYSDATETIME()
	WHERE ProductId=@ProductId AND CustID IN (SELECT CustID FROM #CustList)
		AND @ProductId NOT IN (14,17)
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not update'
	RETURN
	END

	INSERT INTO dbo.Dep_CustProductSetting (CustID, ProductId, IsEnabled,RepUpdateTime)
	SELECT CustID, @ProductId, @IsEnabled, SYSDATETIME()	
	FROM #CustList c
	WHERE NOT EXISTS(SELECT 1 FROM dbo.Dep_CustProductSetting cs WITH (NOLOCK) WHERE cs.CustID = c.CustID AND cs.ProductId=@ProductId)
	IF(@@ERROR<>0)
	BEGIN
		SELECT @ErrMsg='Could not insert'
		RETURN
	END

	-- Write log
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(MILLISECOND,@startRun,@endRun)

	SELECT @LogSPData = '<Lrf_3rdProductUpdCustStatus CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'ProductId="'+ COALESCE(CAST(@ProductId as VARCHAR(20)),SPACE(1)) + '" ' +
						'IsEnabled="'+ COALESCE(CAST(@IsEnabled as VARCHAR(1)),SPACE(1)) + '" ' +
						'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +						
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<Lrf_3rdProductUpdCustStatus CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'ProductId="'+ COALESCE(CAST(@ProductId as VARCHAR(20)),SPACE(1)) + '" ' +
						'IsEnabled="'+ COALESCE(CAST(@IsEnable_Old as VARCHAR(1)),SPACE(1)) + '" ' +
						'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +						
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	BEGIN TRY
	    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2213,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END TRY
    BEGIN CATCH
	    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2213,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END CATCH
END
GO
