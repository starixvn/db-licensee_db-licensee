/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap,wsv_lap,svc_tig" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_LicenseeBetSettingSel] 
	@CustID INT
	,@Product INT
	,@AgentID INT = 0 
	,@Option BIT = 0
	,@SettingStatus TINYINT = 0
AS
/*
	Created: Elodie
	Date: 20150121
	Task : Licensee Setting Configuration - Get bet setting information [#6304]
	DB: DBCUST/CustDB
	Original:

	Revisions:
		- 20150609@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB, use temp table for GameType table)
		- 20151123@Elodie: Support Muay Thai in Licensee Settings function [Redmine: #47801]
		- 20191111@Eden: 3rd party products - Remove InActive Products Phase 2 [Redmine: #118699]
		- 20200616@Johnson: add soccer parlay [redmine:#135261]
		- 20211223@Johnson: adjust the betlimit at the subsidiary agent level [redmine:#165885]
		- 202202220@Elodie: Apply DCS for SB [RedmineID: #167898] 
		- 20220921@Winfred: Licensee DCS setting - HF Get multiple bet limit . [Feature #178013]
		- 20231022@Winfred: NAP LM - Enhance Licensee Bet Setting function [Feature #194623]
		- 20240429@Tacy: Apply @SettingStatus [RedmineID: #201239]
		- 20241106@Johnson: grant permission for svc_tig [RedmineID: #213373]

	Param's Explanation:
		@Product:	1: Sportbook
					161: Number Game					
					202: Keno
		@CustID: superID
		@Option :  0 for Currency Bet Setting OR 1 for Player Bet Setting
	Example: EXEC NAP_LM_LicenseeBetSettingSel @CustID = 916498, @Product = 1
		
*/ 
BEGIN
	SET NOCOUNT ON
	DECLARE @ProductID TINYINT, @MemberID INT, @Agent01 INT = @AgentID
	CREATE TABLE #SportBettypeFilter (ProductID TINYINT, Sporttype SMALLINT, Bettype SMALLINT, IsLive BIT, SettingType TINYINT)
	SELECT @ProductID = CASE	WHEN @Product = 1 THEN 1 
								WHEN @Product = 161 THEN 3
								WHEN @Product = 202 THEN 8 END	
	
	INSERT INTO #SportBettypeFilter (ProductID,SportType,Bettype,IsLive,SettingType)
	SELECT @ProductID AS ProductID,SportType,Bettype,IsLive, SettingType 
	FROM dbo.f_Dep_CustSetting_SportBetTypeSettingSelect(@ProductID,NULL,@SettingStatus)
	
	IF @ProductID = 1 --Sportbook
	BEGIN
		IF @Option = 0
		BEGIN
			IF @AgentID = 0
			BEGIN
				SET @AgentID = @CustID
			END

			SELECT	cs.sporttype AS SportTypeID
					,cs.bettype AS BetTypeID
					,MinBet
					,MaxBet
					,MaxPerMatch
					,MaxPayoutPerMatch
			FROM Dep_CustBetSettingGame_Agent AS cs WITH (NOLOCK) 
				INNER JOIN #SportBettypeFilter pd WITH (NOLOCK) ON pd.SportType = cs.SportType AND pd.BetType = cs.BetType
			WHERE cs.custid = @CustID 
				AND pd.SettingType = 10
		
			SELECT	cs.sporttype AS SportTypeID
					,cs.bettype AS BetTypeID
					,MinBet
					,MaxBet
					,MaxPerMatch
					,MaxPayoutPerMatch
			FROM Dep_CustBetSettingGame_Agent AS cs WITH (NOLOCK) 
				INNER JOIN #SportBettypeFilter pd WITH (NOLOCK) ON pd.SportType = cs.SportType AND pd.BetType = cs.BetType
			WHERE cs.custid = @AgentID 
				AND pd.SettingType = 10
		END
		ELSE
		BEGIN
			IF @AgentID = 0
			BEGIN
				CREATE TABLE #tblmrecommend  (CustID INT PRIMARY KEY)
		
				INSERT INTO #tblmrecommend(CustID)
				SELECT custid FROM custinfo WITH (NOLOCK) WHERE roleid=3
				and username LIKE '%Acc%' and srecommend=@CustID

				SET @Agent01 = (SELECT TOP 1 Custid FROM custInfo WITH(NOLOCK) WHERE srecommend = @CustID AND roleid = 2 
											AND mrecommend NOT IN (SELECT CustID FROM #tblmrecommend) ORDER BY custid ASC)
				
				SET @AgentID = @CustID

				DROP TABLE #tblmrecommend
			END
			
			SET @MemberID = (SELECT TOP 1 Custid FROM custInfo WITH(NOLOCK) WHERE srecommend = @CustID AND recommend = @Agent01 AND roleid = 1 ORDER BY custid ASC)

			SELECT	cs.sporttype AS SportTypeID
					,cs.bettype AS BetTypeID
					,MinBet
					,MaxBet
					,MaxPerMatch
					,MaxPayoutPerMatch
			FROM Dep_CustBetSettingGame_Agent AS cs WITH (NOLOCK) 
				INNER JOIN #SportBettypeFilter pd WITH (NOLOCK) ON pd.SportType = cs.SportType AND pd.BetType = cs.BetType
			WHERE cs.custid = @AgentID 
				AND pd.SettingType = 10

			IF EXISTS (SELECT 1 FROM Dep_CustSettingMode ps WITH (NOLOCK) WHERE CustID = @MemberID AND IsGroupedBetLimit = 1)
			BEGIN
				SELECT	cs.sporttype AS SportTypeID
						,cs.bettype AS BetTypeID
						,MinBet
						,MaxBet
						,MaxPerMatch
						,MaxPayoutPerMatch
				FROM Dep_CustBetSettingGameGroup_Member AS cs WITH (NOLOCK) 
					INNER JOIN #SportBettypeFilter pd WITH (NOLOCK) ON pd.SportType = cs.SportType AND pd.BetType = cs.BetType
				WHERE cs.AgentID = @Agent01 AND pd.SettingType = 10
			END
			ELSE
			BEGIN
				SELECT	cs.sporttype AS SportTypeID
						,cs.bettype AS BetTypeID
						,MinBet
						,MaxBet
						,MaxPerMatch
						,MaxPayoutPerMatch
				FROM Dep_CustBetSettingGame_Member AS cs WITH (NOLOCK) 
					INNER JOIN #SportBettypeFilter pd WITH (NOLOCK) ON pd.SportType = cs.SportType AND pd.BetType = cs.BetType
				WHERE cs.custid = @MemberID AND pd.SettingType = 10
			END
		END
	END
	ELSE IF @ProductID = 3 --Number Game
	BEGIN
		SELECT	cs.sporttype AS SportTypeID
				,cs.bettype AS BetTypeID
				,MinBet
				,MaxBet
				,MaxPerMatch
				,MaxPerNumber AS MaxPerBall
		FROM Dep_CustBetSettingGame_Agent AS cs WITH (NOLOCK) 
			INNER JOIN #SportBettypeFilter pd WITH (NOLOCK) ON pd.SportType = cs.SportType AND pd.BetType = cs.BetType
		WHERE cs.custid = @CustID 
			AND pd.SettingType = 12
	END

	IF @ProductID = 8 --Keno
	BEGIN
		DECLARE @downlines BIT, @DisableDownlines BIT, @DisableSuper BIT
		SELECT @downlines = CASE WHEN EXISTS (	SELECT TOP 1 1 
												FROM custinfo WITH(NOLOCK) 
												WHERE srecommend = @CustID AND roleid = 1 
													AND mrecommend NOT IN (	SELECT custid 
																			FROM custInfo WITH (NOLOCK) 
																			WHERE srecommend = @CustID AND roleid = 3 
																				AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88' + 'CAS%'))) THEN 1 ELSE 0 END

		SELECT @DisableSuper = CASE WHEN cs.CustID IS NULL THEN 1 ELSE (SELECT value FROM dbo.f_CustSetting_ProductStatusSel (cs.bitmapIsDisabled, psp.bitmapOrder)) END
		FROM Dep_CustProductStatus cs WITH(NOLOCK) 
			RIGHT JOIN dbo.custInfo ci WITH (NOLOCK) ON cs.CustID = ci.CustID
			CROSS JOIN #SportBettypeFilter pd WITH (NOLOCK) 
			INNER JOIN dbo.Dep_ProductStatusProfile psp WITH (NOLOCK) ON psp.Bettype = pd.BetType AND psp.Sporttype = pd.SportType
		WHERE ci.custid = @CustID AND pd.SettingType = 4

		SELECT @DisableDownlines = CASE WHEN @downlines = 0	THEN @DisableSuper
										ELSE ISNULL((
												SELECT TOP 1 1
												FROM Dep_CustProductStatus cps_temp WITH(NOLOCK) 
													INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON cps_temp.CustID = ci.CustID
													CROSS JOIN #SportBettypeFilter pd WITH (NOLOCK)
													INNER JOIN dbo.Dep_ProductStatusProfile psp WITH (NOLOCK) ON psp.Bettype = pd.BetType AND psp.Sporttype = pd.SportType
												WHERE srecommend = @CustID AND pd.SettingType = 4 AND roleid = 1
													AND mrecommend NOT IN (	SELECT custid 
																			FROM custInfo WITH (NOLOCK) 
																			WHERE srecommend = @CustID AND roleid = 3 
																				AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88' + 'CAS%'))
													AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps_temp.bitmapIsDisabled, PSP.bitmapOrder)) = 1
												), 0) END

		SELECT	cs.SportType		AS SportTypeID,
				cs.BetType			AS BetTypeID, 
				cs.MinBet,			
				cs.MaxBet,		
				cs.MaxPerMatch,		 
				@DisableSuper		AS DisableSuper, 
				@DisableDownlines	AS DisableDownline
		FROM dbo.Dep_CustBetSetting_Agent cs WITH (NOLOCK)
			INNER JOIN #SportBettypeFilter pd WITH (NOLOCK) ON pd.SportType = cs.SportType AND pd.BetType = cs.BetType
		WHERE cs.CustID = @CustID 
			AND pd.SettingType = 2
	END 
END
GO

