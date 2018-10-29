/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,Dot_Member,vnteam" viewers="vnteam" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberBAPositionTakingDCS]		
	@CustID		INT,
	@ModifyBy	INT,
	@IsBA		BIT,		
	@IP			VARCHAR(40),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS

/*
Created: 20181024@Winnie
Task : PT DCS for BA member
DB: DBCUST/CustDB
Revisions:
	- 20181024@Winnie: PT DCS for BA member [RedmineID: #1000721]
*/

BEGIN
	DECLARE @startRun		DATETIME  
	DECLARE @endRun			DATETIME  
	DECLARE @duration		INT  
	DECLARE @IsGroupPTOLD	BIT
	DECLARE @IsGroupPTNew	BIT
	DECLARE @xml			XML
	DECLARE @LogSPData		VARCHAR(MAX)  
	DECLARE @TrackingValue2 VARCHAR(MAX)  
	DECLARE @AgentID		INT
	CREATE TABLE #Sporttype(SporttypeID INT,BetypeID INT,IsLive INT,PRIMARY KEY(SporttypeID,BetypeID,IsLive))
	DECLARE  @Dep_CustPTGroupSetting_MemberOLD TABLE	
	(
		CustID		INT,
		Sporttype	SMALLINT,
		Bettype		SMALLINT,
		IsLive		BIT,
		SuperPT		SMALLMONEY,
		MasterPT	SMALLMONEY,
		AgentPT		SMALLMONEY
	)


	SET @startRun = GETDATE()  

	SELECT @IsGroupPTOLD=IsGroupedPT FROM Dep_CustSettingMode WITH(NOLOCK) WHERE CustID=@CustID	

	SELECT @AgentID=recommend FROM Customer WITH(NOLOCK) WHERE custid=@CustID

	IF @IsGroupPTOLD=0
	BEGIN
		INSERT INTO @Dep_CustPTGroupSetting_MemberOLD(CustID,Sporttype,Bettype,IsLive,SuperPT,MasterPT,AgentPT)
		SELECT CustID,Sporttype,Bettype,IsLive,SuperPT,MasterPT,AgentPT
		FROM Dep_CustPTSetting_Member WITH(NOLOCK)
		WHERE CustID=@CustID
	END
	ELSE
	BEGIN
		INSERT INTO @Dep_CustPTGroupSetting_MemberOLD(CustID,Sporttype,Bettype,IsLive,SuperPT,MasterPT,AgentPT)
		SELECT @CustID,Sporttype,Bettype,IsLive,SuperPT,MasterPT,AgentPT
		FROM Dep_CustPTGroupSetting_Member WITH(NOLOCK)
		WHERE AgentID=@AgentID
	END

	INSERT INTO #Sporttype(SporttypeID,BetypeID,IsLive)
	SELECT SportType,BetType,IsLive
	FROM Dep_ProductSettingDetail a WITH(NOLOCK)
		INNER JOIN Dep_ProductSetting b WITH(NOLOCK) ON a.ProductSettingID=b.ProductSettingID
	WHERE IsApplyBA=1 AND SettingType=1

	SET @xml = (
		SELECT	
				@CustID							AS '@CustID',
				@ModifyBy						AS '@ModifyBy',			
				@IP								AS '@IP',
				@IsGroupPTOLD					AS '@IsGroupedPT',
				(
					SELECT	SportType									AS '@SportType',
							BetType										AS '@BetType',
							CONVERT(DECIMAL(10,2), cs.SuperPT/100.0)	AS '@SuperPT',
							CONVERT(DECIMAL(10,2), cs.MasterPT/100.0)	AS '@MasterPT',
							CONVERT(DECIMAL(10,2), cs.AgentPT/100.0)	AS '@AgentPT'
					FROM @Dep_CustPTGroupSetting_MemberOLD cs
					FOR XML PATH('PT'),
					TYPE
				)
		FOR XML PATH('Lrf_CustomerUpdMemberBAPositionTakingDCS'),
		TYPE
		)

	SET @TrackingValue2 = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

	IF(@IsBA=1)
	BEGIN
		UPDATE t
			SET SuperPT=0,
				MasterPT=0,
				AgentPT=0
		FROM @Dep_CustPTGroupSetting_MemberOLD t 
			INNER JOIN #Sporttype s ON t.Sporttype=s.SporttypeID AND t.Bettype=s.BetypeID AND t.IsLive=s.IsLive
		
	END
	ELSE
	BEGIN
		UPDATE t
			SET SuperPT=a.SuperPT,
				MasterPT=a.MasterPT,
				AgentPT=a.AgentPT
		FROM @Dep_CustPTGroupSetting_MemberOLD t 
			INNER JOIN Dep_CustPTSetting_Agent a WITH(NOLOCK) ON t.Sporttype=a.SportType AND t.Bettype=a.BetType AND t.IsLive=a.IsLive
			INNER JOIN #Sporttype s ON t.Sporttype=s.SporttypeID AND t.Bettype=s.BetypeID AND t.IsLive=s.IsLive
		WHERE a.CustID=@AgentID 
	END
		
	IF EXISTS(SELECT TOP 1 1 FROM @Dep_CustPTGroupSetting_MemberOLD a 
								INNER JOIN Dep_CustPTGroupSetting_Member b ON a.Sporttype=b.SportType AND a.Bettype=b.BetType AND a.IsLive=b.IsLive
								WHERE (a.AgentPT<>b.AgentPT OR a.MasterPT<>b.MasterPT OR a.SuperPT<>b.SuperPT) AND b.AgentID=@AgentID)
	BEGIN
		IF @IsGroupPTOLD=0
		BEGIN
			UPDATE m
				SET m.SuperPT=o.SuperPT,m.MasterPT=o.MasterPT,m.AgentPT=o.AgentPT
			FROM  Dep_CustPTSetting_Member m WITH(ROWLOCK,UPDLOCK)
				INNER JOIN @Dep_CustPTGroupSetting_MemberOLD o ON m.Sporttype=o.SportType AND m.Bettype=o.BetType AND m.IsLive=o.IsLive
				INNER JOIN #Sporttype s ON o.Sporttype=s.SporttypeID AND o.Bettype=s.BetypeID AND o.IsLive=s.IsLive
			WHERE m.CustID=@CustID 

			IF @@ERROR<>0
			BEGIN
				SELECT @ErrCode=100
				SELECT @ErrMsg='Error when processing PT DCS for BA member'
				RETURN
			END
		END
		ELSE
		BEGIN
			UPDATE Dep_CustSettingMode
				SET IsGroupedPT=0
			WHERE CustID=@CustID
				
			IF @@ERROR<>0
			BEGIN
				SELECT @ErrCode=100
				SELECT @ErrMsg='Error when processing PT DCS for BA member'
				RETURN
			END

			UPDATE m
				SET m.SuperPT=o.SuperPT,m.MasterPT=o.MasterPT,m.AgentPT=o.AgentPT
			FROM  Dep_CustPTSetting_Member m WITH(ROWLOCK,UPDLOCK)
				INNER JOIN @Dep_CustPTGroupSetting_MemberOLD o ON m.Sporttype=o.SportType AND m.Bettype=o.BetType AND m.IsLive=o.IsLive
				INNER JOIN #Sporttype s ON o.Sporttype=s.SporttypeID AND o.Bettype=s.BetypeID AND o.IsLive=s.IsLive
			WHERE m.CustID=@CustID 

			IF @@ERROR<>0
			BEGIN
				SELECT @ErrCode=100
				SELECT @ErrMsg='Error when processing PT DCS for BA member'
				RETURN
			END

			INSERT INTO [dbo].[Dep_CustPTSetting_Member]
				([CustID]
				,[SportType]
				,[BetType]
				,[IsLive]
				,[SuperPT]
				,[MasterPT]
				,[AgentPT])
			SELECT 
				[CustID]
				,[SportType]
				,[BetType]
				,[IsLive]
				,[SuperPT]
				,[MasterPT]
				,[AgentPT]
			FROM @Dep_CustPTGroupSetting_MemberOLD o WHERE NOT EXISTS(SELECT 1 FROM Dep_CustPTSetting_Member m WITH(NOLOCK) 
																				WHERE m.CustID=o.CustID AND m.SportType=o.Sporttype AND m.BetType=o.Bettype AND m.IsLive=o.IsLive)
			IF @@ERROR<>0
			BEGIN
				SELECT @ErrCode=100
				SELECT @ErrMsg='Error when processing PT DCS for BA member'
				RETURN
			END
		END
	END
	ELSE
	BEGIN
		IF @IsGroupPTOLD=0
		BEGIN
			UPDATE Dep_CustSettingMode
				SET IsGroupedPT=1
			WHERE CustID=@CustID

			IF @@ERROR<>0
			BEGIN
				SELECT @ErrCode=100
				SELECT @ErrMsg='Error when processing PT DCS for BA member'
				RETURN
			END
				
			DELETE FROM Dep_CustPTSetting_Member WHERE CustID=@CustID
		END
	END					

	SELECT @IsGroupPTNew=IsGroupedPT FROM Dep_CustSettingMode WITH(NOLOCK) WHERE CustID=@CustID	


	SET @xml = (
		SELECT	
				@CustID							AS '@CustID',
				@ModifyBy						AS '@ModifyBy',			
				@IP								AS '@IP',
				@IsGroupPTNew					AS '@IsGroupedPT',
				(
					SELECT	SportType									AS '@SportType',
							BetType										AS '@BetType',
							CONVERT(DECIMAL(10,2), cs.SuperPT/100.0)	AS '@SuperPT',
							CONVERT(DECIMAL(10,2), cs.MasterPT/100.0)	AS '@MasterPT',
							CONVERT(DECIMAL(10,2), cs.AgentPT/100.0)	AS '@AgentPT'
					FROM Dep_CustPTSetting_Member cs WITH(NOLOCK)
					WHERE cs.CustID=@CustID
					FOR XML PATH('PT'),
					TYPE
				)
		FOR XML PATH('Lrf_CustomerUpdMemberBAPositionTakingDCS'),
		TYPE
		)

	SET @LogSPData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)  

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
		 @UserID = @ModifyBy,  
		 @CustID = @CustID,  
		 @ActionID = 2718,  
		 @TrackingValue = @LogSPData,  
		 @TrackingValue2 = @TrackingValue2,  
		 @duration = @duration  
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
		 @UserID = @ModifyBy,  
		 @CustID = @CustID,  
		 @ActionID = 2718,  
		 @TrackingValue = @LogSPData,  
		 @TrackingValue2 = @TrackingValue2,  
		 @duration = @duration
	END CATCH
END