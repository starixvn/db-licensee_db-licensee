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
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 202202220@Elodie: Apply DCS for SB [RedmineID: #167898] 

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
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	DECLARE @PT VARCHAR(MAX), @PT_xml XML, @ProductID TINYINT, @ProductSettingID INT, @AgentID INT
	DECLARE @SportBettypeFilter TABLE(SportType INT,Bettype INT,IsLive BIT)		

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

	SELECT @ProductID = CASE	WHEN @Sporttype = 1 THEN 1 
								WHEN @Sporttype = 161 THEN 3
								WHEN @Sporttype = 202 THEN 8 END
	
	SELECT  @ProductSettingID=ProductSettingID from Dep_ProductSetting WITH(NOLOCK) WHERE ProductID=@ProductID AND SettingType=1

	INSERT INTO @SportBettypeFilter (SportType,Bettype,IsLive)
	SELECT DISTINCT SportType,Bettype,IsLive
	FROM Dep_ProductSetting ps WITH(NOLOCK) 
		INNER JOIN Dep_ProductSettingDetail d WITH(NOLOCK) ON ps.ProductSettingID=d.ProductSettingID  
	WHERE ProductID = @ProductID AND SettingType=1		

	CREATE TABLE #SMAList(custid INT PRIMARY KEY, roleid TINYINT, isfinished BIT DEFAULT(0))
	INSERT INTO #SMAList(custid, RoleId)
	SELECT custid, roleid
	FROM custinfo WITH(NOLOCK)	
	WHERE srecommend = @CustID
		AND mrecommend NOT IN (SELECT custid FROM custInfo WITH (NOLOCK) 
								WHERE srecommend = @CustID AND roleid = 3 
									AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88' + 'CAS%'))

		AND roleid IN (4,3,2)
	
	SELECT @ptVALUE = @ptVALUE * 100
	SET @PT_xml = (
		SELECT (
					SELECT  sporttype									AS '@SportType',
                            bettype										AS '@BetType',
                            isLive										AS '@IsLive',
                            dbo.f_FomatNumericToChar(@ptVALUE)			AS '@PT'
					FROM @SportBettypeFilter
					FOR XML PATH('PT'), 
                    TYPE
				)
		FOR XML PATH('ROOT'), 
        TYPE)
	SET @PT = CAST(@PT_xml AS VARCHAR(MAX))
	
	IF NOT EXISTS (SELECT 1 FROM Dep_LicenseeProductSetting d WITH(NOLOCK)WHERE ProductSettingID=@ProductSettingID AND CustID=@CustID)
		INSERT INTO Dep_LicenseeProductSetting(CustID,ProductSettingID)
		VALUES( @CustID,@ProductSettingID)

	IF EXISTS (	SELECT 1 
				FROM @SportBettypeFilter ft 
					INNER JOIN dbo.Dep_CustPTSetting_Agent bl WITH (NOLOCK) ON ft.SportType = bl.sporttype AND ft.BetType = bl.bettype AND ft.IsLive = bl.IsLive
				WHERE bl.custid = @CustID)
		UPDATE a
			SET
				SuperPT  = @ptVALUE
				,MasterPT = @ptVALUE
				,AgentPT  = @ptVALUE
		FROM dbo.Dep_CustPTSetting_Agent a WITH(ROWLOCK,UPDLOCK)
			INNER JOIN @SportBettypeFilter t ON a.SportType=t.SportType AND a.BetType=t.BetType AND t.IsLive = a.IsLive
		WHERE a.custid = @CustID
	ELSE
		INSERT INTO dbo.Dep_CustPTSetting_Agent(CustID,SportType,BetType,IsLive,SuperPT,MasterPT,AgentPT)
		SELECT @CustID,SportType,BetType,IsLive,@ptVALUE,@ptVALUE,@ptVALUE
		FROM @SportBettypeFilter t

	IF EXISTS (	SELECT 1 
				FROM @SportBettypeFilter ft 
					INNER JOIN dbo.Dep_CustPTSetting_Agent bl WITH (NOLOCK) ON ft.SportType = bl.sporttype AND ft.BetType = bl.bettype AND ft.IsLive = bl.IsLive
					INNER JOIN #SMAList s ON bl.CustID = s.custid
				WHERE s.roleid = 3)
		UPDATE a
			SET
				SuperPT  = 0
				,MasterPT = @ptVALUE
				,AgentPT  = 0
		FROM dbo.Dep_CustPTSetting_Agent a WITH(ROWLOCK,UPDLOCK)
			INNER JOIN @SportBettypeFilter t ON a.SportType=t.SportType AND a.BetType=t.BetType AND t.IsLive = a.IsLive
			INNER JOIN #SMAList s ON a.CustID = s.custid
		WHERE s.roleid = 3
	ELSE
		INSERT INTO dbo.Dep_CustPTSetting_Agent(CustID,SportType,BetType,IsLive,SuperPT,MasterPT,AgentPT)
		SELECT s.custid,SportType,BetType,IsLive,0,@ptVALUE,0
		FROM @SportBettypeFilter t
			CROSS APPLY #SMAList s
		WHERE s.roleid = 3

	IF EXISTS (	SELECT 1 
				FROM @SportBettypeFilter ft 
					INNER JOIN dbo.Dep_CustPTSetting_Agent bl WITH (NOLOCK) ON ft.SportType = bl.sporttype AND ft.BetType = bl.bettype AND ft.IsLive = bl.IsLive
					INNER JOIN #SMAList s ON bl.CustID = s.custid
				WHERE s.roleid = 2)
		UPDATE a
		SET SuperPT   = 0
			,MasterPT = 0
			,AgentPT  = @ptVALUE
		FROM dbo.Dep_CustPTSetting_Agent a WITH(ROWLOCK,UPDLOCK)
			INNER JOIN @SportBettypeFilter t ON a.SportType=t.SportType AND a.BetType=t.BetType AND t.IsLive = a.IsLive
			INNER JOIN #SMAList s ON a.CustID = s.custid
		WHERE s.roleid = 2
	ELSE
		INSERT INTO dbo.Dep_CustPTSetting_Agent(CustID,SportType,BetType,IsLive,SuperPT,MasterPT,AgentPT)
		SELECT s.custid,SportType,BetType,IsLive,0,0,@ptVALUE
		FROM @SportBettypeFilter t
			CROSS APPLY #SMAList s
		WHERE s.roleid = 2

	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) s
		SET s.isfinished = 1,
			@AgentID = custid
		FROM #SMAList s
		WHERE isfinished = 0 AND roleid = 2

		IF @@ROWCOUNT =  0 BREAK

		EXEC Acc_Dep_DynamicCustSetting_01	
			@CustID=@AgentID,
			@PT=@PT,					
			@ProductID=@ProductID	
	END

	SELECT TOP 1 @ProductID = ProductID
	FROM Dep_ProductSettingDetail pd WITH(NOLOCK) 
		INNER JOIN Dep_ProductSetting p WITH(NOLOCK) ON pd.ProductSettingID = p.ProductSettingID
	WHERE SportType = @Sporttype AND SettingType = 1

	IF NOT EXISTS (SELECT 1 FROM Dep_ProductSetting ps WITH(NOLOCK) 
									INNER JOIN Dep_LicenseeProductSetting d WITH(NOLOCK) ON ps.ProductSettingID=d.ProductSettingID WHERE ProductID=@ProductID AND SettingType = 1 AND CustID = @CustID)
	BEGIN
		INSERT INTO Dep_LicenseeProductSetting(CustID,ProductSettingID)
		SELECT @CustID, ProductSettingID
		FROM Dep_ProductSetting WITH(NOLOCK)
		WHERE ProductID = @ProductID AND SettingType = 1
	END	

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
