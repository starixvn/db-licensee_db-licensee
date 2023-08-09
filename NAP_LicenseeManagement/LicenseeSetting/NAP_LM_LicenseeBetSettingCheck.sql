/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_LicenseeBetSettingCheck] 
	@CustID INT	
	,@AgentID INT = 0
	,@UpdBetLimit VARCHAR(MAX) = ''
	,@Option BIT = 0
	,@ExistedMember BIT = 0
	,@IsNewMember BIT = 0	
	,@UpdNewMember VARCHAR(MAX) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20230224@Winfred
	Task : NAP LM Configuration - Check bet settings for Enhance Bet Setting 
	DB: DBCUST/CustDB
	Original:

	Revisions:
		   - 20230224@Winfred: NAP LM - Enhance Bet Setting function for AM to use [redmine:#178105]
		   - 20230630@Winfred: When update Currency Bet Setting in case All Subsidiaries + All players, system check violated with its own players [redmine:#190506]
		   - 20230717@Winfred: Enhance performace  [redmine:#191470]
		   - 20230722@Winfred: NAP LM - Enhance Bet Setting function for AM to use - New Case [redmine:#178105]
    Param's Explanation:
		- @CustID : super ID
		- @AgentID : 0 for All Subsidiary AND <> 0 for only Specific Subsidiary 
		- @Option :  0 for Currency Bet Setting OR 1 for Player Bet Setting
		- @ExistedMember : existing player 
		- @IsNewMember : Default Bet Setting 
		- @UpdBetLimit :
		<ROOT>
				<BL SportType=1 Bettype=1 MinBet=100 MaxBet=1000 MaxPerMatch=1000 MaxPerNumber=1000 MaxPayoutPerMatch=1000
				/>
		</ROOT>
*/ 
BEGIN
	SET NOCOUNT ON
	DECLARE @xml XML, @iDoc INT,@Site VARCHAR(10),@CurrencyID INT, @ErrName VARCHAR(Max) = '', @currency	NVARCHAR(50) = '', @code NVARCHAR(50) = '',@username	VARCHAR(30) = ''
	CREATE TABLE #SportTypeBetType(SportType INT,Bettype INT,MinBet	MONEY,MaxBet MONEY,MaxPerMatch	MONEY,MaxPerNumber	MONEY,MaxPayoutPerMatch	MONEY,PRIMARY KEY(Sporttype ,Bettype))
	CREATE TABLE #NewDefault(SportType INT,Bettype INT,MinBet	MONEY,MaxBet MONEY,MaxPerMatch	MONEY,MaxPerNumber	MONEY,MaxPayoutPerMatch	MONEY,PRIMARY KEY(Sporttype ,Bettype))
	
	SELECT @ErrCode = 0, @ErrMsg =''
	IF @ExistedMember=1
	BEGIN
		EXEC dbo.NAP_LM_CustomerSelCheckAllowedDownlines
		@custid = @CustID
		,@Language = 'E'
		,@ErrMsg = @ErrMsg OUTPUT
		,@ErrCode=@ErrCode OUTPUT
	END

	IF @ErrCode <> 0 
		RETURN 

	BEGIN TRY
		IF @UpdBetLimit <> ''
		BEGIN
			--Parse XML
			EXECUTE	sp_xml_preparedocument @iDoc OUTPUT, @UpdBetLimit

			INSERT INTO #SportTypeBetType (SportType, Bettype, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch )
			SELECT	ox.SportType, ox.Bettype,  
				CASE WHEN ox.MinBet = '' THEN null ELse CAST(ox.MinBet AS MONEY) END AS MinBet, 
				CASE WHEN ox.MaxBet = '' THEN null ELse CAST(ox.MaxBet AS MONEY) END AS MaxBet,
				CASE WHEN ox.MaxPerMatch = '' THEN null ELse CAST(ox.MaxPerMatch AS MONEY) END AS MaxPerMatch, 
				CASE WHEN ox.MaxPerNumber = '' THEN null ELse CAST(ox.MaxPerNumber AS MONEY) END AS MaxPerNumber, 
				CASE WHEN ox.MaxPayoutPerMatch = '' THEN null ELse CAST(ox.MaxPayoutPerMatch AS MONEY) END AS MaxPayoutPerMatch
			FROM OPENXML (@iDoc, '/ROOT/BL', 1) 
			WITH (
				SportType			INT
			,	Bettype				INT
			,	MinBet				VARCHAR(20)	
			,	MaxBet				VARCHAR(20)	
			,	MaxPerMatch			VARCHAR(20)	
			,	MaxPerNumber		VARCHAR(20)	
			,	MaxPayoutPerMatch	VARCHAR(20)		
			) AS ox;
		
			EXECUTE sp_xml_removedocument @iDoc;
		END
	END TRY

	BEGIN CATCH
		SET @ErrCode = 100
		SET @ErrMsg = N'Unable to process update NAP Bet Limit due to invalid parameters, please try again.'
		RETURN
	END CATCH;

	BEGIN TRY
		IF @UpdNewMember <> ''
		BEGIN
			SET @iDoc = 0
			EXECUTE	sp_xml_preparedocument @iDoc OUTPUT, @UpdNewMember

			INSERT INTO #NewDefault (SportType, Bettype, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch )
			SELECT	ox.SportType, ox.Bettype,  
				CASE WHEN ox.MinBet = '' THEN null ELse CAST(ox.MinBet AS MONEY) END AS MinBet, 
				CASE WHEN ox.MaxBet = '' THEN null ELse CAST(ox.MaxBet AS MONEY) END AS MaxBet,
				CASE WHEN ox.MaxPerMatch = '' THEN null ELse CAST(ox.MaxPerMatch AS MONEY) END AS MaxPerMatch, 
				CASE WHEN ox.MaxPerNumber = '' THEN null ELse CAST(ox.MaxPerNumber AS MONEY) END AS MaxPerNumber, 
				CASE WHEN ox.MaxPayoutPerMatch = '' THEN null ELse CAST(ox.MaxPayoutPerMatch AS MONEY) END AS MaxPayoutPerMatch
			FROM OPENXML (@iDoc, '/ROOT/BL', 1) 
			WITH (
				SportType			INT
			,	Bettype				INT
			,	MinBet				VARCHAR(20)	
			,	MaxBet				VARCHAR(20)	
			,	MaxPerMatch			VARCHAR(20)	
			,	MaxPerNumber		VARCHAR(20)	
			,	MaxPayoutPerMatch	VARCHAR(20)		
			) AS ox;

			EXECUTE sp_xml_removedocument @iDoc;
		END
	END TRY

	BEGIN CATCH
		SET @ErrCode = 100
		SET @ErrMsg = N'Unable to process update NAP Bet Limit due to invalid parameters, please try again.'
		RETURN
	END CATCH;

	SELECT @Site = site, @CurrencyID = currency, @username = username  FROM Customer c WITH(NOLOCK) WHERE custid = @CustID
	SELECT @code = Code , @currency = currency  FROM exchange e WITH(NOLOCK) WHERE ExchangeId = @CurrencyID

	CREATE TABLE #Subsidiary(custid INT PRIMARY KEY, username VARCHAR(100) )
	CREATE TABLE #ExcludeMember(custid INT PRIMARY KEY)
	CREATE TABLE #Upline(custid INT PRIMARY KEY, CashOut NVARCHAR(50), OddsAdj NVARCHAR(50), ClearBal NVARCHAR(50), Bettrade NVARCHAR(50), username NVARCHAR(50))

	CREATE TABLE #DummyMaster(custid INT PRIMARY KEY)
	INSERT INTO #DummyMaster(custid)
	SELECT custid FROM custinfo WITH(NOLOCK)
	WHERE srecommend = @CustID AND roleid=3
		AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88' + 'CAS%')
		
	IF @AgentID = 0
	BEGIN
		INSERT INTO #Upline(custid, CashOut, OddsAdj, ClearBal, Bettrade, username)
		SELECT ci.custid 
				, ci.username + 'CashOut' AS CashOut
				, @Site + @currency + '01OddsAdj' AS OddsAdj
				, ci.username + 'ClearBal' AS ClearBal
				, ci.username + 'BetTrade' AS Bettrade
				, ci.username
		FROM custinfo ci WITH(NOLOCK)
		WHERE srecommend = @CustID AND roleid=2 AND mrecommend NOT IN (SELECT custid FROM #DummyMaster)	
	END
	ELSE
	BEGIN
		INSERT INTO #Upline(custid, CashOut, OddsAdj, ClearBal, Bettrade, username)
		SELECT ci.custid 
				, ci.username + 'CashOut' AS CashOut
				, @Site + @currency + '01OddsAdj' AS OddsAdj
				, ci.username + 'ClearBal' AS ClearBal
				, ci.username + 'BetTrade' AS Bettrade
				, ci.username
		FROM custinfo ci WITH(NOLOCK)
		WHERE srecommend = @CustID AND roleid=2 
		AND mrecommend NOT IN (SELECT custid FROM #DummyMaster)	
		AND ci.custid = @AgentID
	END

	--Currency Bet Setting
	IF @Option = 0
	BEGIN
		INSERT INTO #ExcludeMember(custid)
		SELECT c.custid
		FROM custinfo c WITH(NOLOCK)
			INNER JOIN #Upline a ON c.recommend = a.custid
		WHERE c.roleid = 1 AND (c.username = a.OddsAdj OR c.username = a.ClearBal OR  c.username = a.CashOut OR c.username = a.Bettrade)

		IF EXISTS (SELECT TOP 1 1 FROM #Upline WHERE custid = 835046)
		BEGIN
			INSERT INTO #ExcludeMember(custid) VALUES (12012421),(12012429) --CashoutPro, CashoutProChargesRMB
		END 

		IF EXISTS (SELECT TOP 1 1 FROM #Upline WHERE custid = 35167174)
		BEGIN
			INSERT INTO #ExcludeMember(custid) VALUES (35167175) --ig128TB0CashOut
		END 

		IF @ExistedMember = 0
		BEGIN
			IF @AgentID = 0
			BEGIN
				INSERT INTO #Subsidiary(custid, username)
				SELECT a.custid, a.username
				FROM #Upline a
					CROSS APPLY ( 
								SELECT TOP 1 recommend
								FROM #SportTypeBetType s 
									CROSS JOIN custinfo ci WITH(NOLOCK)
									CROSS APPLY (SELECT TOP 1 CustID, SportType, BetType, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch
												FROM Dep_CustBetSettingGame_Member m WITH(NOLOCK)
												WHERE ci.custid = m.CustID AND m.SportType = s.SportType AND m.Bettype = s.Bettype
												) cs
								WHERE ci.recommend = a.custid AND ci.roleid = 1 
									AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeMember WHERE custid = ci.custid)
									AND s.MaxBet IS NOT NULL
									AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
									(s.MinBet <= cs.MinBet AND s.MaxBet >= cs.MaxBet AND s.MaxPerMatch >= cs.MaxPerMatch AND s.MaxPayoutPerMatch >= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

						) KQ
	
				UPDATE a
				SET a.username = a.username + CASE WHEN NULLIF(s.OperatorID,'') IS NOT NULL THEN ' ('+s.OperatorID+')'
									WHEN ISNULL(s.OperatorID,'') = '' AND s.AgentID IS NOT NULL THEN ' (sub)'
									ELSE '' END
				FROM #Subsidiary a
					LEFT JOIN [SiteConfig].[dbo].[Operator] s WITH(NOLOCK) ON a.Custid=s.AgentID

				SET @ErrName = (SELECT STRING_AGG(username, ', ') WITHIN GROUP (ORDER BY username) FROM #Subsidiary)

				IF @ErrName <> ''
				BEGIN			
					SELECT @ErrCode = 101,
						@ErrMsg = 'The value bet setting you just input is violating its own players. Please review and update again!
									List of Subsidiaries whose existing Players are violated ' + @ErrName
					RETURN						
				END	
			END
			ELSE
			BEGIN
				SELECT TOP 1 @ErrCode = 102
				FROM #Upline a
					CROSS APPLY ( 
								SELECT TOP 1 recommend
								FROM #SportTypeBetType s 
									CROSS JOIN custinfo ci WITH(NOLOCK)
									CROSS APPLY (SELECT TOP 1 CustID, SportType, BetType, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch
												FROM Dep_CustBetSettingGame_Member m WITH(NOLOCK)
												WHERE ci.custid = m.CustID AND m.SportType = s.SportType AND m.Bettype = s.Bettype
												) cs
								WHERE ci.recommend = a.custid AND ci.roleid = 1 
									AND NOT EXISTS (SELECT TOP 1 1 FROM #ExcludeMember WHERE custid = ci.custid)
									AND s.MaxBet IS NOT NULL
									AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
									(s.MinBet <= cs.MinBet AND s.MaxBet >= cs.MaxBet AND s.MaxPerMatch >= cs.MaxPerMatch AND s.MaxPayoutPerMatch >= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

						) KQ

				IF @ErrCode <> 0
				BEGIN			
					SELECT @ErrCode = 102,
						@ErrMsg = 'The value bet setting you just input is violating its own players. Please review and update again!'
					RETURN						
				END	
			END
		END

		IF @UpdNewMember = ''
		BEGIN
			IF  @IsNewMember = 0 AND @ExistedMember = 0
			BEGIN

				SELECT TOP 1 @ErrCode = CASE WHEN cs.AgentID IS NULL THEN 106 ELSE  103 END
				FROM Dep_CustBetLimit_Special cs WITH(NOLOCK)
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
				WHERE cs.CurrencyID = @CurrencyID AND cs.Site = @Site AND cs.MaxBet IS NOT NULL AND cs.MaxPerMatch IS NOT NULL
					AND 1 = CASE WHEN @AgentID = 0 AND cs.AgentID IS NULL THEN 1  
								 WHEN @AgentID <> 0  AND cs.AgentID = @AgentID THEN 1  
								 ELSE 0 END
					AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
							(s.MinBet <= cs.MinBet AND s.MaxBet >= cs.MaxBet AND s.MaxPerMatch >= cs.MaxPerMatch AND s.MaxPayoutPerMatch >= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

				IF @ErrCode <> 0
				BEGIN			
					SELECT @ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!' -- CB-03
					RETURN						
				END	
			END

			IF @AgentID <> 0 AND @IsNewMember = 1
			BEGIN
				SELECT TOP 1 @ErrCode = 108
				FROM Dep_CustBetLimit_Special cs WITH(NOLOCK)
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
				WHERE cs.CurrencyID = @CurrencyID AND cs.Site = @Site AND cs.MaxBet IS NOT NULL AND cs.MaxPerMatch IS NOT NULL
					AND cs.AgentID IS NULL
					AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
							(s.MinBet >= cs.MinBet AND s.MaxBet <= cs.MaxBet AND s.MaxPerMatch <= cs.MaxPerMatch AND s.MaxPayoutPerMatch <= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

				IF @ErrCode <> 0
				BEGIN			
					SELECT @ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!'
					RETURN						
				END	
			END 
		END
		
		IF @IsNewMember = 0 AND @ExistedMember = 0
		BEGIN
			IF @AgentID = 0 AND @UpdNewMember <> ''
			BEGIN
				INSERT INTO #Subsidiary(custid, username)
				SELECT a.custid, a.username
				FROM #Upline a
					CROSS APPLY ( 
								SELECT TOP 1 AgentID
								FROM #NewDefault s 
									CROSS APPLY (SELECT TOP 1 AgentID AS AgentID, SportType, BetType, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch
												FROM Dep_CustBetLimit_Special m WITH(NOLOCK)
												WHERE a.custid = m.AgentID AND m.Site = @Site AND m.CurrencyID = @CurrencyID AND  m.SportType = s.SportType AND m.Bettype = s.Bettype
												) cs
								WHERE cs.MaxBet IS NOT NULL
									AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
									(s.MinBet <= cs.MinBet AND s.MaxBet >= cs.MaxBet AND s.MaxPerMatch >= cs.MaxPerMatch AND s.MaxPayoutPerMatch >= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

						) KQ
	
				UPDATE a
				SET a.username = a.username + CASE WHEN NULLIF(s.OperatorID,'') IS NOT NULL THEN ' ('+s.OperatorID+')'
									WHEN ISNULL(s.OperatorID,'') = '' AND s.AgentID IS NOT NULL THEN ' (sub)'
									ELSE '' END
				FROM #Subsidiary a
					LEFT JOIN [SiteConfig].[dbo].[Operator] s WITH(NOLOCK) ON a.Custid=s.AgentID

				SET @ErrName = (SELECT STRING_AGG(username, ', ') WITHIN GROUP (ORDER BY username) FROM #Subsidiary)

				IF @ErrName <> ''
				BEGIN			
					SELECT @ErrCode = 109,
						@ErrMsg = 'The Default Bet Setting of Currency is violated with Default Bet Setting of Subsidiary. Please review and update again!
									List of Subsidiaries whose DBS are violated ' + @ErrName
					RETURN						
				END	
			END
			-- Update DBS and don't Update Current Bet limit
			SELECT TOP 1 @ErrCode = 103
			FROM #Upline a
				CROSS APPLY ( 
							SELECT TOP 1 custid
							FROM #NewDefault s 
								CROSS APPLY (SELECT TOP 1 CustID, SportType, BetType, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch
											FROM Dep_CustBetSettingGame_Agent m WITH(NOLOCK)
											WHERE a.custid = m.CustID AND m.SportType = s.SportType AND m.Bettype = s.Bettype
											) cs
								LEFT JOIN #SportTypeBetType sb ON cs.SportType = sb.SportType AND cs.BetType = sb.Bettype
							WHERE sb.SportType IS NULL AND sb.Bettype IS NULL AND s.MaxBet IS NOT NULL
								AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
								(s.MinBet >= cs.MinBet AND s.MaxBet <= cs.MaxBet AND s.MaxPerMatch <= cs.MaxPerMatch AND s.MaxPayoutPerMatch <= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

					) KQ

			IF @ErrCode <> 0
			BEGIN			
				SELECT @ErrCode = 103,
					@ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!'
				RETURN						
			END	
		END

		IF @UpdNewMember <> ''  AND @AgentID <> 0
		BEGIN
			IF @IsNewMember = 1
			BEGIN
				SELECT TOP 1 @ErrCode = 108
				FROM Dep_CustBetLimit_Special cs WITH(NOLOCK)
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
					INNER JOIN #NewDefault n ON cs.SportType = n.SportType AND cs.BetType = n.Bettype
				WHERE cs.CurrencyID = @CurrencyID AND cs.Site = @Site AND cs.MaxBet IS NOT NULL AND cs.MaxPerMatch IS NOT NULL
					AND EXISTS(SELECT TOP 1 1  FROM Dep_CustBetLimit_Special WITH(NOLOCK) 
																WHERE CurrencyID = @CurrencyID AND Site = @Site AND MaxBet IS NOT NULL 
																AND AgentID IS NULL AND SportType = s.SportType AND BetType = s.Bettype)  
																AND cs.AgentID = @AgentID 
					AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
									   (n.MinBet <= n.MaxBet AND n.MaxBet <= n.MaxPerMatch AND n.MaxPerMatch <= n.MaxPayoutPerMatch) AND
						(n.MinBet <= s.MinBet AND n.MaxBet >= s.MaxBet AND n.MaxPerMatch >= s.MaxPerMatch AND n.MaxPayoutPerMatch >= s.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

				IF @ErrCode <> 0
				BEGIN			
					SELECT @ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!' -- CB-03
					RETURN						
				END	
			END
			ELSE
			BEGIN
				-- Update DBS of Subsidiary and it violates with DBS of Currency
				SELECT TOP 1 @ErrCode = 110
				FROM Dep_CustBetLimit_Special cs WITH(NOLOCK)
					INNER JOIN #NewDefault n ON cs.SportType = n.SportType AND cs.BetType = n.Bettype
				WHERE cs.CurrencyID = @CurrencyID AND cs.Site = @Site AND cs.MaxBet IS NOT NULL AND cs.MaxPerMatch IS NOT NULL AND cs.AgentID IS NULL 
					AND 1 = CASE WHEN ((n.MinBet <= n.MaxBet AND n.MaxBet <= n.MaxPerMatch AND n.MaxPerMatch <= n.MaxPayoutPerMatch) AND 
									   (n.MinBet <= n.MaxBet AND n.MaxBet <= n.MaxPerMatch AND n.MaxPerMatch <= n.MaxPayoutPerMatch) AND
						(n.MinBet >= cs.MinBet AND n.MaxBet <= cs.MaxBet AND n.MaxPerMatch <= cs.MaxPerMatch AND n.MaxPayoutPerMatch <= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

				IF @ErrCode <> 0
				BEGIN			
					SELECT @ErrMsg = 'The new Default Bet Setting of Subsidiary is violated with Default Bet Setting of Currency. Please review and update again!!' -- CB-07
					RETURN						
				END	
			END
		END

		SELECT TOP 1 @ErrCode = 103
		FROM #SportTypeBetType cs 
			INNER JOIN #NewDefault s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
		WHERE  s.MaxBet IS NOT NULL
				AND 1 = CASE WHEN @AgentID = 0 THEN 1 
							 WHEN @AgentID <> 0 AND @IsNewMember = 0 AND @ExistedMember = 0 THEN 1 ELSE 0 END 
				AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
					(s.MinBet >= cs.MinBet AND s.MaxBet <= cs.MaxBet AND s.MaxPerMatch <= cs.MaxPerMatch AND s.MaxPayoutPerMatch <= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

		IF @ErrCode <> 0
		BEGIN			
			SELECT @ErrCode = 103,
				@ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!'
			RETURN						
		END	
	END	
	ELSE 
	BEGIN
		INSERT INTO #Subsidiary(custid, username)
		SELECT a.custid, a.username
		FROM #Upline a
			CROSS APPLY ( 
						SELECT TOP 1 recommend
						FROM #SportTypeBetType s 
							CROSS JOIN custinfo ci WITH(NOLOCK)
							CROSS APPLY (SELECT TOP 1 CustID, SportType, BetType, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch
										FROM Dep_CustBetSettingGame_Agent m WITH(NOLOCK)
										WHERE ci.custid = m.CustID AND m.SportType = s.SportType AND m.Bettype = s.Bettype
										) cs
						WHERE ci.custid = a.custid AND s.MaxBet IS NOT NULL
							AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
								(s.MinBet >= cs.MinBet AND s.MaxBet <= cs.MaxBet AND s.MaxPerMatch <= cs.MaxPerMatch AND s.MaxPayoutPerMatch <= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END
				) KQ
		
		UPDATE a
		SET a.username = a.username + CASE WHEN NULLIF(s.OperatorID,'') IS NOT NULL THEN ' ('+s.OperatorID+')'
							WHEN ISNULL(s.OperatorID,'') = '' AND s.AgentID IS NOT NULL THEN ' (sub)'
							ELSE '' END
		FROM #Subsidiary a
			LEFT JOIN [SiteConfig].[dbo].[Operator] s WITH(NOLOCK) ON a.Custid=s.AgentID
	
		SET @ErrName = (SELECT STRING_AGG(username, ', ') WITHIN GROUP (ORDER BY username) FROM #Subsidiary)
		
		IF @ErrName <> ''
		BEGIN	
			IF @AgentID = 0
			BEGIN
				SELECT @ErrCode = 104,
					@ErrMsg = 'The value bet setting you just input is violating with its ' + @Site + ' - ' + @code + ' ('+@username+') . 
								Please review and update again! List of Subsidiaries are violated: ' 
					+ @ErrName
				RETURN	
			END	
			ELSE
			BEGIN
				SELECT @ErrCode = 105,
				@ErrMsg = 'The value bet setting you just input is violating with its Subsidiary. Please review and update again!'
				RETURN	
			END
		END	

		--=============================================================================================================================

		IF @UpdNewMember = '' AND @AgentID <> 0 AND @IsNewMember = 1
		BEGIN
			SELECT TOP 1 @ErrCode = 107
			FROM Dep_CustBetLimit_Special cs WITH(NOLOCK)
				INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
			WHERE cs.CurrencyID = @CurrencyID AND cs.Site = @Site AND cs.MaxBet IS NOT NULL AND cs.MaxPerMatch IS NOT NULL
				AND cs.AgentID IS NULL
				AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
						(s.MinBet >= cs.MinBet AND s.MaxBet <= cs.MaxBet AND s.MaxPerMatch <= cs.MaxPerMatch AND s.MaxPayoutPerMatch <= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

			IF @ErrCode <> 0
			BEGIN		
				SELECT @ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!'
				RETURN						
			END	
		END

		IF @UpdNewMember <> '' AND @ExistedMember = 1 
		BEGIN
			IF @IsNewMember = 1 AND @AgentID <> 0
			BEGIN
				SELECT TOP 1 @ErrCode = 107
				FROM Dep_CustBetLimit_Special cs WITH(NOLOCK)
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
					INNER JOIN #NewDefault n ON cs.SportType = n.SportType AND cs.BetType = n.Bettype
				WHERE cs.CurrencyID = @CurrencyID AND cs.Site = @Site AND cs.MaxBet IS NOT NULL AND cs.MaxPerMatch IS NOT NULL
					 AND EXISTS(SELECT TOP 1 1  FROM Dep_CustBetLimit_Special WITH(NOLOCK) 
												WHERE CurrencyID = @CurrencyID AND Site = @Site AND MaxBet IS NOT NULL 
												AND AgentID IS NULL AND SportType = s.SportType AND BetType = s.Bettype)  
												AND cs.AgentID = @AgentID
					AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
									   (n.MinBet <= n.MaxBet AND n.MaxBet <= n.MaxPerMatch AND n.MaxPerMatch <= n.MaxPayoutPerMatch) AND
						(n.MinBet <= s.MinBet AND n.MaxBet >= s.MaxBet AND n.MaxPerMatch >= s.MaxPerMatch AND n.MaxPayoutPerMatch >= s.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

				IF @ErrCode <> 0
				BEGIN		
					SELECT @ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!'
					RETURN						
				END	
			END

			SELECT TOP 1 @ErrCode = 107
			FROM #SportTypeBetType cs 
				INNER JOIN #NewDefault s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
			WHERE @IsNewMember = 1 AND s.MaxBet IS NOT NULL AND 1 = CASE WHEN ((s.MinBet <= s.MaxBet AND s.MaxBet <= s.MaxPerMatch AND s.MaxPerMatch <= s.MaxPayoutPerMatch) AND 
						(s.MinBet <= cs.MinBet AND s.MaxBet >= cs.MaxBet AND s.MaxPerMatch >= cs.MaxPerMatch AND s.MaxPayoutPerMatch >= cs.MaxPayoutPerMatch)) THEN 0 ELSE 1 END

			IF @ErrCode <> 0
			BEGIN	
				SELECT @ErrCode = 107,
					@ErrMsg = 'The value bet setting you just input is violating its Default Bet Setting. Please review and update Default Bet Setting!'
				RETURN						
			END	
		END

	END	

	DROP TABLE #Subsidiary
	DROP TABLE #SportTypeBetType
	DROP TABLE #DummyMaster
	DROP TABLE #NewDefault
	DROP TABLE #Upline
	DROP TABLE #ExcludeMember
 END
 
 