/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
USE CustDB
GO
CREATE PROCEDURE [dbo].[NAP_LM_LicenseeBetSettingUpd] 
	@CustID INT	
	,@Sporttype INT
	,@Bettype INT = 0
	,@MinBet MONEY = 0
	,@MaxBet MONEY = 0
	,@MaxPerMatch MONEY = 0
	,@MaxPayoutPerMatch MONEY = 0
	,@MaxPerBall MONEY = 0
	,@ExistedMember BIT
	,@AgentID INT = 0
	,@IsAgentOnly BIT = 0
	,@UpdateMinBet BIT = 0
	,@UpdateMaxBet BIT = 0
	,@UpdateMPM BIT = 0
	,@UpdateMaxPayoutPM BIT = 0
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
	   - 20190412@Winnie: Licesee Management-Licensee setting - Cannot update betting limit SMA only for big line  - Redmine: 96951
	   - 20211224@Johnson: Adjust Bet Limit for Sub Agent [redmine: #165885]
	   - 202202220@Elodie: Apply DCS for SB [RedmineID: #167898] 
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
	IF @ExistedMember=1
	BEGIN
		EXEC DBEXT.bodb02.dbo.NAP_LM_CustomerSelCheckAllowedDownlines
		@custid = @CustID
		,@Language = 'E'
		,@ErrMsg = @ErrMsg OUTPUT
		,@ErrCode=@ErrCode OUTPUT
	END
	IF @ErrCode <> 0 
		RETURN 
	
	IF @sporttype NOT IN (161,202)--checking sportbook
	BEGIN
		EXEC NAP_LM_CustomerBetSettingCheck			
			@CustID = @CustID	
			,@Sporttype = @Sporttype
			,@Bettype = @Bettype
			,@MinBet = @MinBet
			,@MaxBet = @MaxBet
			,@MaxPerMatch = @MaxPerMatch
			
			,@ExistedMember = @ExistedMember
			,@AgentID = @AgentID
			,@IsAgentOnly = @IsAgentOnly
			,@UpdateMinBet = @UpdateMinBet
			,@UpdateMaxBet = @UpdateMaxBet
			,@UpdateMPM = @UpdateMPM
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
		
		IF @ErrCode <> 0 
			RETURN;
	END
	
	CREATE TABLE #temp(custid INT PRIMARY KEY, roleid TINYINT, isfinished BIT DEFAULT(0))
	INSERT INTO #temp(custid, roleid)
	SELECT custid, roleid
	FROM customer c WITH(NOLOCK)	
	WHERE srecommend = @CustID
			AND mrecommend NOT IN (SELECT custid FROM custinfo WITH(NOLOCK)
									WHERE srecommend = @CustID 
										AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88' + 'CAS%')
										AND roleid=3)
			AND c.username NOT LIKE '%CashOut%'
			AND c.username  NOT LIKE '%OddsAdj%'
			AND c.username  NOT LIKE '%ClearBal%'
			AND c.username  NOT LIKE '%Bettrade%'			
			AND 1 =  CASE WHEN @sporttype IN (161,202) THEN 1
						ELSE 
						CASE WHEN @IsAgentOnly = 1 AND @ExistedMember = 0 AND ((custid = @AgentID AND @AgentID <> 0) OR (roleid = 2 AND @AgentID = 0))THEN 1
							WHEN @IsAgentOnly = 1 AND @ExistedMember = 1 AND (@AgentID <> 0 AND recommend = @AgentID) OR (@AgentID =0 AND roleid IN (1,2)) THEN 1
							WHEN @IsAgentOnly = 0 AND @ExistedMember = 0 AND ((@AgentID <> 0 AND (custid = @AgentID OR roleid IN (3,4))) OR (@AgentID = 0 AND roleid IN (2,3,4))) THEN 1
							WHEN @IsAgentOnly = 0 AND @ExistedMember = 1 AND (@AgentID <> 0 AND (recommend = @AgentID OR roleid IN (3,4)) OR @AgentID =0) THEN 1
							ELSE 0 END
						END	
	IF @Sporttype IN (1,2,3,5,8,10,11,99,9901,9902,43) --Sportbook
		OR @Sporttype = 161 --NumberGame
	BEGIN
		DELETE t
		FROM #temp t 
			INNER JOIN Dep_CustSettingMode cm ON t.custid = cm.CustID
		WHERE roleid = 1 AND cm.IsGroupedBetLimit = 1
	END

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
		  
			IF @Sporttype IN (161,202) OR @UpdateMinBet = 1 OR @UpdateMaxBet = 1 OR @UpdateMPM = 1 OR @UpdateMaxPayoutPM = 1
				EXEC Acc_CustSetting3rd_11 
					@ids = @ids, 
					@srecommend = @CustID, 
					@Sporttype = @Sporttype, 
					@Bettype = @Bettype, 
					@MinBet = @MinBet, 
					@MaxBet = @MaxBet, 					
					@MaxPerMatch = @MaxPerMatch, 
					@MaxPerBall = @MaxPerBall, 
					@MaxPayoutPerMatch = @MaxPayoutPerMatch, 
					@ExistedMember = @ExistedMember, 
					@UpdateMinBet = @UpdateMinBet,
					@UpdateMaxBet = @UpdateMaxBet,
					@UpdateMPM = @UpdateMPM,
					@UpdateMaxPayoutPM = @UpdateMaxPayoutPM,
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
						'AgentID="'+ coalesce(cast(@AgentID AS VARCHAR(10)),space(1))+ '" ' +
						'AgentOnly="'+ coalesce(cast(@IsAgentOnly AS VARCHAR(1)),space(1))+ '" ' +
						'UpdateMinBet="'+ coalesce(cast(@UpdateMinBet AS VARCHAR(1)),space(1))+ '" ' +
						'UpdateMaxBet="'+ coalesce(cast(@UpdateMinBet AS VARCHAR(1)),space(1))+ '" ' +
						'UpdateMPM="'+ coalesce(cast(@UpdateMPM AS VARCHAR(1)),space(1))+ '" ' +
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
						'AgentID="'+ coalesce(cast(@AgentID AS VARCHAR(10)),space(1))+ '" ' +
						'AgentOnly="'+ coalesce(cast(@IsAgentOnly AS VARCHAR(1)),space(1))+ '" ' +
						'UpdateMinBet="'+ coalesce(cast(@UpdateMinBet AS VARCHAR(1)),space(1))+ '" ' +
						'UpdateMaxBet="'+ coalesce(cast(@UpdateMinBet AS VARCHAR(1)),space(1))+ '" ' +
						'UpdateMPM="'+ coalesce(cast(@UpdateMPM AS VARCHAR(1)),space(1))+ '" ' +
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
