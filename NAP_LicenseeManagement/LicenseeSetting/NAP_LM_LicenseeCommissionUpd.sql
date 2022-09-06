/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_LicenseeCommissionUpd] 
	@CustID INT
	,@Sporttype INT
	,@Bettype INT
	,@Discount MONEY
	,@UserID INT = 0
	,@Language varchar(2) = 'E'
	,@IP varchar(15)=''
	,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20150121
	Task : Licensee Setting Configuration - Update Commission [#6304]
	DB: DBCUST/CustDB
	Original:

	Revisions:
		- 202209010@Elodie: Insert Dep_LicenseeProductSetting in case no data [RedmineID: #177383] 

	Param's Explanation:
	Example:	DECLARE @ErrCode INT = 0, @ErrMsg NVARCHAR(4000) = ''
				EXEC NAP_LM_LicenseeCommissionUpd @CustID = 16947245, @Sporttype = 153, @Bettype = 51, @Discount = 0.03, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
				SELECT @ErrCode, @ErrMsg
		
*/ 
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	DECLARE @ProductID SMALLINT, @SettingType TINYINT

	SET @startRun = getdate()
	SELECT @ErrCode = 0, @ErrMsg =''

	EXEC DBEXT.bodb02.dbo.NAP_LM_CustomerSelCheckAllowedDownlines
		@custid = @CustID
		,@Sporttype = @Sporttype
		,@Language = 'E'
		,@ErrMsg = @ErrMsg OUTPUT
		,@ErrCode=@ErrCode OUTPUT

	IF @ErrCode <> 0 
		RETURN 

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
			
			EXEC Acc_CustSetting3rd_13 @ids = @ids, @Sporttype = @Sporttype, @Bettype = @Bettype, @Discount = @Discount

			IF @rowcnt < 10000 BREAK

			WAITFOR DELAY '00:00:00.28'
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrCode  = ERROR_NUMBER()   					
		RETURN
	END CATCH	

	SELECT TOP 1 @ProductID = ProductID, @SettingType = SettingType
	FROM Dep_ProductSettingDetail pd WITH(NOLOCK) 
		INNER JOIN Dep_ProductSetting p WITH(NOLOCK) ON pd.ProductSettingID = p.ProductSettingID
	WHERE SportType = @Sporttype AND SettingType IN (9)

	IF NOT EXISTS (SELECT 1 FROM Dep_ProductSetting ps WITH(NOLOCK) 
									INNER JOIN Dep_LicenseeProductSetting d WITH(NOLOCK) ON ps.ProductSettingID=d.ProductSettingID WHERE ProductID=@ProductID AND SettingType = @SettingType AND CustID = @CustID)
	BEGIN
		INSERT INTO Dep_LicenseeProductSetting(CustID,ProductSettingID)
		SELECT @CustID, ProductSettingID
		FROM Dep_ProductSetting WITH(NOLOCK)
		WHERE ProductID = @ProductID AND SettingType = @SettingType
	END	

	DECLARE @LogSPData VARCHAR(8000)

	SELECT  @LogSPData ='<NAP_LM_LicenseeCommissionUpd custid="'+ coalesce(cast(@CustID AS VARCHAR(20)),space(1))+ '" ' +
						'Sporttype="'+ coalesce(cast(@Sporttype AS VARCHAR(20)),space(1))+ '" ' +
						'Bettype="'+ coalesce(cast(@Bettype AS VARCHAR(20)),space(1))+ '" ' +
						'Discount="'+ coalesce(cast(@Discount AS VARCHAR(50)),space(1))+ '" ' +
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
			@ActionID = 2613, 
			@TrackingValue = @LogSPData,
			@duration = @duration
	END TRY
	BEGIN CATCH
		SELECT  @LogSPData ='<NAP_LM_LicenseeCommissionUpd custid="'+ coalesce(cast(@CustID AS VARCHAR(20)),space(1))+ '" ' +
						'Sporttype="'+ coalesce(cast(@Sporttype AS VARCHAR(20)),space(1))+ '" ' +
						'Bettype="'+ coalesce(cast(@Bettype AS VARCHAR(20)),space(1))+ '" ' +
						'Discount="'+ coalesce(cast(@Discount AS VARCHAR(50)),space(1))+ '" ' +
						'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1))+ '" ' +
						'Language="'+ coalesce(cast(@Language as varchar(2)),space(1))+ '" ' +
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+ '" ' +
						'ErrCode="' + coalesce(cast(ERROR_NUMBER() as varchar(50)),space(1)) + 
						'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1)) + '" />'
					
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@UserID = @UserID,
			@CustID = @CustID,
			@ActionID = 2613, 
			@TrackingValue = @LogSPData,
			@duration = @duration	
	END CATCH		
END

GO
GRANT EXECUTE ON [dbo].[NAP_LM_LicenseeCommissionUpd] TO [bodbadminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[NAP_LM_LicenseeCommissionUpd] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LM_LicenseeCommissionUpd] TO [vnteam] AS [dbo]