/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb_Licensee]
GO

ALTER PROCEDURE [dbo].[Lrf_LicenseeBAHistoryIns]
	@LicenseeID INT,
	@CustID INT,--member
	@ModifyBy INT,
	@GroupComm decimal(9,8),
	@Comm1x2 decimal(9,8),
	@OtherComm decimal(9,8),
	@ugroup varchar(3),
	@Langkey VARCHAR(10) = 'en-US',
	@IP VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
Created: 20111101@Henry
Task : Insert BA Member running to table LicenseeBAHistory
DB: DBCUST/bodb_Licensee

Revisions:
	- 20120307@Jim:  remove parameter @danger (remove column licenseeBAHistory.danger)
	- 20130413@Jim: support multi language
	- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

Param's Explanation:

*/
BEGIN
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	DECLARE @LogSPData VARCHAR(5000)
	SET @startRun = GETDATE()

	IF NOT EXISTS(
		SELECT TOP 1 1 FROM [LicenseeBAHistory] WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND CustID = @CustID AND [Status] = 'Running'
	)
	BEGIN
		INSERT INTO [LicenseeBAHistory] (LicenseeID, CustID, OnDate, OnBy,[Status], GroupComm, [1x2Comm], [OtherComm], [UGroup])
		VALUES (@LicenseeID,@CustID,GETDATE(),@ModifyBy,'Running',@GroupComm,@Comm1x2,@OtherComm,@ugroup)
	
		IF (@@ERROR <> 0)
		BEGIN
			SELECT @ErrMsg = 
							CASE @Langkey 
								WHEN 'en-US' THEN 'Process turn on BA is unsuccessful !'
								ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200013,@Langkey)
							END, @ErrCode = 100
		END	
	END
	ELSE
	BEGIN
		SELECT @ErrMsg = 
						CASE @Langkey 
							WHEN 'en-US' THEN 'This member has already enabled BA !'
							ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200014,@Langkey)
						END, @ErrCode = 101
	END
	
	SELECT @LogSPData = '<Lrf_LicenseeBAHistoryIns LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@ModifyBy as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupComm="'+ COALESCE(CAST(@GroupComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'Ugroup="'+ COALESCE(CAST(@ugroup as VARCHAR(10)),SPACE(1)) + '" ' +
		'1x2Comm="'+ COALESCE(CAST(@Comm1x2 as VARCHAR(50)),SPACE(1)) + '" ' +
		'OtherComm="'+ COALESCE(CAST(@OtherComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
		--'Danger="'+ COALESCE(CAST(@Danger as VARCHAR(40)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'

	SET @endRun = GETDATE()
	SET @duration  = datediff (millisecond,@startRun,@endRun)

	EXEC dbo.LAP_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @ModifyBy,
			@CustID = @CustID,
			@ActionID = 2401,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = '',
			@duration = @duration
END
GO
