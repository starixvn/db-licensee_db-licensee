SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Lrf_3rdProductUpdCustStatus    Script Date: 7/22/2015 1:09:34 PM ******/

 

/****** Object:  Stored Procedure dbo.Lrf_3rdProductUpdCustStatus    Script Date: 6/10/2015 10:51:17 AM ******/
CREATE PROCEDURE	dbo.Lrf_3rdProductUpdCustStatus  
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
	SELECT val FROM dbo.strSplit(@CustIDs,',')
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not update'
	RETURN
	END

	UPDATE dbo.Dep_CustProductSetting WITH (ROWLOCK, UPDLOCK)
	SET IsEnabled = @IsEnabled
	WHERE ProductId=@ProductId AND CustID IN (SELECT CustID FROM #CustList)
		AND @ProductId NOT IN (14,17)
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not update'
	RETURN
	END
	IF (@ProductId<>14)
	BEGIN
		INSERT INTO dbo.Dep_CustProductSetting (CustID, ProductId, IsEnabled)
		SELECT CustID, @ProductId, @IsEnabled	
		FROM #CustList c
		WHERE NOT EXISTS(SELECT 1 FROM dbo.Dep_CustProductSetting cs WITH (NOLOCK) WHERE cs.CustID = c.CustID AND cs.ProductId=@ProductId)
		IF(@@ERROR<>0)
		BEGIN
			SELECT @ErrMsg='Could not insert'
			RETURN
		END
	END
	--- MicroGaming
	ELSE IF (@ProductID = 14)
		BEGIN 
			UPDATE dbo.CustInfo WITH (ROWLOCK,UPDLOCK)
			SET DisableMicrogameLC = CASE @IsEnabled WHEN 1 THEN 0 ELSE 1 END
			WHERE CustID = @CustID	
		END
	ELSE IF (@ProductID = 17)
		BEGIN 
			UPDATE dbo.CustInfo WITH (ROWLOCK,UPDLOCK)
			SET DisableMicrogameRnG = CASE @IsEnabled WHEN 1 THEN 0 ELSE 1 END
			WHERE CustID = @CustID	
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

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Lrf_3rdProductUpdCustStatus] TO [bodbLicenseeNet]
GO 
