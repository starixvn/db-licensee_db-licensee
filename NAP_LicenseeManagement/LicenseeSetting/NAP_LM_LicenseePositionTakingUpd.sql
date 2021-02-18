/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_LicenseePositionTakingUpd] 
	@CustID INT
	,@Sporttype INT
	,@ptVALUE MONEY
	,@UserID INT = 0
	,@Language varchar(2) = 'E'
	,@IP varchar(15)=''
	,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20150121
	Task : Licensee Setting Configuration - Update Position taking [#6304]
	DB: DBCUST/CustDB
	Original:

	Revisions:
		- 20150121@Elodie - Add revision
		- 20201214@Winfred: Adjust PT value with 4 decimal places for SB  [redmine: #146574]
		- 20210208@Eden: exclude BA member when adjust PT for Sportbook [redmine: #150191]
		
	Param's Explanation:
		@Product:	1: Sportbook
					161: Number Game
					180: Virtual sport
					151: Horse Racing
					202: Keno
	Example:	DECLARE @ErrCode INT = 0, @ErrMsg NVARCHAR(4000) = ''
				EXEC NAP_LM_LicenseePositionTakingUpd @CustID = 16947245, @Sporttype = 1, @ptValue = 0.9, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
				SELECT @ErrCode, @ErrMsg	
*/ 
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = getdate()
	SELECT @ErrCode = 0, @ErrMsg =''

	EXEC DBEXT.bodb02.dbo.NAP_LM_CustomerSelCheckAllowedDownlines
		@custid = @CustID
		,@Sporttype = @Sporttype
		,@isUpdatePT = 1
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
	
	--Exclude BA member for SB
	IF @Sporttype = 1
		DELETE t
		FROM #temp t
			INNER JOIN Dep_CustBAActive b WITH(NOLOCK)	ON b.CustId = t.custid

	BEGIN TRY
		DECLARE @ids VARCHAR(MAX), @rowcnt INT
		WHILE (1=1)
		BEGIN
			SELECT @ids = ''
	
			UPDATE TOP (4000) #temp
			SET @ids = @ids + CASE @ids WHEN '' THEN '' ELSE ',' END + CAST(custid AS VARCHAR(12))
				,isfinished = 1
			FROM #temp
			WHERE isfinished = 0

			SELECT @rowcnt = @@rowcount	

			EXEC Acc_CustSetting3rd_12 @ids = @ids, @Sporttype = @Sporttype, @ptVALUE = @ptVALUE

			IF @rowcnt < 4000 BREAK

			WAITFOR DELAY '00:00:00.28'
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrCode  = ERROR_NUMBER()   					
		RETURN
	END CATCH	

	DECLARE @LogSPData VARCHAR(8000)

	SELECT  @LogSPData ='<NAP_LM_LicenseePositionTakingUpd custid="'+ coalesce(cast(@CustID AS VARCHAR(20)),space(1))+ '" ' +
						'Sporttype="'+ coalesce(cast(@Sporttype AS VARCHAR(20)),space(1))+ '" ' +
						'PT="'+ coalesce(dbo.f_FomatNumericToChar(@ptVALUE ),space(1))+ '" ' +
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
			@ActionID = 2717, 
			@TrackingValue = @LogSPData,
			@duration = @duration
	END TRY
	BEGIN CATCH
		SELECT  @LogSPData ='<NAP_LM_LicenseePositionTakingUpd custid="'+ coalesce(cast(@CustID AS VARCHAR(20)),space(1))+ '" ' +
						'Sporttype="'+ coalesce(cast(@Sporttype AS VARCHAR(20)),space(1))+ '" ' +
						'PT="'+ coalesce(dbo.f_FomatNumericToChar(@ptVALUE),space(1))+ '" ' +
						'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1))+ '" ' +
						'Language="'+ coalesce(cast(@Language as varchar(2)),space(1))+ '" ' +
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+ '" ' +
						'ErrCode="' + coalesce(cast(ERROR_NUMBER() as varchar(50)),space(1)) + 
						'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1)) + '" />'
					
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@UserID = @UserID,
			@CustID = @CustID,
			@ActionID = 2717, 
			@TrackingValue = @LogSPData,
			@duration = @duration	
	END CATCH		
END

GO
