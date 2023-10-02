/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_LicenseeBetLimitUpd] 
	@CustID INT	
	,@AgentID INT = 0
	,@UpdBetLimit VARCHAR(MAX)
	,@Option BIT = 0
	,@ExistedMember BIT = 0
	,@IsNewMember BIT = 0	
	,@UpdNewMember VARCHAR(MAX) = ''
	,@UserID INT = 0
	,@Language varchar(2) = 'E'
	,@IP VARCHAR(15)=''
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
		   - 20230629@Winfred: NAP LM - PRO - Licensee Bet Setting - Currency filter has not taken data according to Currency Code [redmine:#190436]
		   - 20230707@Winfred: NAP LM - Insert icorrect data in Dep_CustBetSettingGame_Member for players have isGroupBetLimit = 1 [redmine:#191020]
		   - 20230717@Winfred: Enhance performace  [redmine:#191470]
		   - 20230722@Winfred: NAP LM - Enhance Bet Setting function for AM to use - New Case [redmine:#178105]
		   - 20230929@Winfred: Bet Setting of players not updated in case update Player Bet Setting (all players) [redmine:#194669]
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

	DECLARE @xml XML, @iDoc INT,@Site VARCHAR(10),@CurrencyID INT, @Currency NVARCHAR(100) ,@Subsidiary NVARCHAR(100), @ErrName VARCHAR(Max) = ''
	, @startRun DATETIME, @endRun DATETIME, @duration INT, @ProductID SMALLINT = 1, @logSpData  NVARCHAR(MAX), @logSpData_Old  NVARCHAR(MAX), @ActionID INT, @LicenseeID INT, @CustIDList VARCHAR(MAX), @ActionDefaultID SMALLINT, @IsNotDBS BIT  = 0, @UplineUpdate SMALLINT = 0
	
	CREATE TABLE #SportBettypeFilter (ProductID TINYINT, Sporttype SMALLINT, Bettype SMALLINT, IsLive BIT, SettingType TINYINT)
	CREATE TABLE #SportTypeBetType_History(SportType INT,Bettype INT,MinBet	MONEY,MaxBet MONEY,MaxPerMatch	MONEY,MaxPerNumber	MONEY,MaxPayoutPerMatch	MONEY,PRIMARY KEY(Sporttype ,Bettype))
	CREATE TABLE #NewDefault_History(SportType INT,Bettype INT,AgentID	INT,MinBet	MONEY,MaxBet MONEY,MaxPerMatch	MONEY,MaxPerNumber	MONEY,MaxPayoutPerMatch	MONEY, ActionDefaultID SMALLINT DEFAULT(12),isfinished BIT DEFAULT(0),UplineUpdate SMALLINT DEFAULT(0))
	CREATE NONCLUSTERED INDEX px_NewDefaultH ON #NewDefault_History (AgentID,Sporttype ,Bettype) 
	
	CREATE TABLE #AgentLog(custid INT PRIMARY KEY,isfinished BIT DEFAULT(0),UplineUpdate SMALLINT DEFAULT(0), STT INT IDENTITY)
	CREATE TABLE #SportTypeBetType(SportType INT,Bettype INT,MinBet	MONEY,MaxBet MONEY,MaxPerMatch	MONEY,MaxPerNumber	MONEY,MaxPayoutPerMatch	MONEY,PRIMARY KEY(Sporttype ,Bettype))
	CREATE TABLE #NewDefault(SportType INT,Bettype INT,MinBet MONEY,MaxBet MONEY,MaxPerMatch MONEY,MaxPerNumber	MONEY,MaxPayoutPerMatch	MONEY,PRIMARY KEY(Sporttype ,Bettype))

	SET @startRun = GETDATE()
			
	EXEC NAP_LM_LicenseeBetSettingCheck			
		@CustID = @CustID	
		,@AgentID = @AgentID
		,@UpdBetLimit = @UpdBetLimit
		,@Option = @Option
		,@ExistedMember = @ExistedMember
		,@IsNewMember = @IsNewMember
		,@UpdNewMember = @UpdNewMember
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
		
	IF @ErrCode <> 0 
		RETURN;

	BEGIN TRY
		IF @UpdBetLimit IS NOT NULL AND @UpdBetLimit <> ''
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
		SELECT @@ERROR
		SET @ErrCode = 100
		SET @ErrMsg = N'Unable to process update NAP Bet Limit due to invalid parameters, please try again.'
		RETURN
	END CATCH;

	BEGIN TRY
		IF @UpdNewMember IS NOT NULL AND @UpdNewMember <> ''
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
		SELECT @@ERROR
		SET @ErrCode = 100
		SET @ErrMsg = N'Unable to process update NAP Bet Limit due to invalid parameters, please try again.'
		RETURN
	END CATCH;

	SELECT @Site = site, @CurrencyID = c.currency, @Currency = e.Code + '(' + c.username + ')' 		
	FROM Customer c WITH(NOLOCK) 
		INNER JOIN exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
	WHERE custid = @CustID

	SELECT @LicenseeID = [site].SiteID 
	FROM dbo.[Site] ibcsite 
		LEFT JOIN bodb_Licensee.dbo.Lrf_view_site_list [site] (NOLOCK) ON ibcsite.siteid=[site].IbcSiteID
	WHERE islicensee=1 AND [site].SiteName = @Site

	CREATE TABLE #DummyMaster(custid INT PRIMARY KEY)
	INSERT INTO #DummyMaster(custid)
	SELECT custid FROM custinfo WITH(NOLOCK)
	WHERE srecommend = @CustID AND roleid=3
		AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88' + 'CAS%')

	IF EXISTS (SELECT 1 FROM #SportTypeBetType ps)
	BEGIN
		IF (EXISTS (SELECT 1 FROM #SportTypeBetType ps WHERE SportType NOT IN (161,202)) OR 
			EXISTS (SELECT 1 FROM #NewDefault ps WHERE SportType NOT IN (161,202)))
		--checking sportbook
		BEGIN
			SET @ProductID = 1
		END	
		ELSE
		BEGIN
			IF ( EXISTS (SELECT 1 FROM #SportTypeBetType ps WHERE SportType IN (161)) OR 
				 EXISTS (SELECT 1 FROM #NewDefault ps WHERE SportType IN (161)))
			BEGIN
				SET @ProductID = 3
			END
			ELSE
			BEGIN
				SET @ProductID = 8
			END
		END
	END
	
	INSERT INTO #SportBettypeFilter (ProductID,SportType,Bettype,IsLive,SettingType)
	SELECT @ProductID AS ProductID,SportType,Bettype,IsLive, SettingType 
	FROM dbo.f_Dep_CustSetting_SportBetTypeSettingSelect(@ProductID,10)

	CREATE TABLE #tmpCustTemp (CustID INT PRIMARY KEY)
	CREATE TABLE #Agent(custid INT,STT INT IDENTITY(1,1) PRIMARY KEY, Subsidiary NVARCHAR(100))

	CREATE TABLE #temp(custid INT PRIMARY KEY, recommend INT, roleid TINYINT, Subsidiary NVARCHAR(100), isfinished BIT DEFAULT(0))
	INSERT INTO #temp(custid, recommend, roleid, Subsidiary)
	SELECT custid, recommend, roleid , username
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
	AND 1 = CASE WHEN EXISTS (SELECT 1 FROM #SportTypeBetType ps WHERE SportType IN (161,202)) THEN 1
			ELSE 
			CASE WHEN @Option = 0 AND @ExistedMember = 0 AND ((@AgentID <> 0 AND (custid = @AgentID OR (roleid IN (3,4)))) OR (roleid IN (2,3,4) AND @AgentID = 0)) THEN 1
			WHEN @Option = 0 AND @ExistedMember = 1 AND ((@AgentID <> 0 AND (recommend = @AgentID OR roleid IN (3,4))) OR (@AgentID =0 AND roleid IN (1,2,3,4))) THEN 1
			WHEN @Option = 1 AND ((@AgentID <> 0 AND (recommend = @AgentID AND roleid IN (1,2))) OR (@AgentID = 0 AND roleid IN (1,2))) THEN 1 ELSE 0 END
			END
	
	INSERT INTO #Agent(custid, Subsidiary)
	SELECT c.custid, c.Subsidiary + CASE WHEN NULLIF(s.OperatorID,'') IS NOT NULL THEN ' ('+s.OperatorID+')'
							WHEN ISNULL(s.OperatorID,'') = '' AND s.AgentID IS NOT NULL THEN ' (sub)'
							ELSE '' END	AS 	Subsidiary
	FROM #temp c
		LEFT JOIN [SiteConfig].[dbo].[Operator] s WITH(NOLOCK) ON c.Custid=s.AgentID
	WHERE roleid = 2

	IF EXISTS (SELECT 1 FROM #SportTypeBetType ps WHERE SportType IN (1,2,3,5,8,10,11,99,9901,9902,43,161,50,9907)) --Sportbook VS NumberGame 
	BEGIN
		DELETE t
		FROM #temp t 
			INNER JOIN Dep_CustSettingMode cm ON t.custid = cm.CustID
		WHERE roleid = 1 AND cm.IsGroupedBetLimit = 1
	END
	IF @Option = 0
	BEGIN
		SET @ActionID = 5574
	END
	ELSE 
	BEGIN 
		SET @ActionID = 5575 
	END
	IF @UpdBetLimit IS NOT NULL AND @UpdBetLimit <> ''
	BEGIN
		BEGIN TRY
			DECLARE @ids VARCHAR(MAX),@SMAs VARCHAR(MAX), @rowcnt INT ,@Recommend INT, @row_STT INT = 1 ,@UpdCurency BIT = 0
			IF @Option = 0 AND @AgentID = 0
			BEGIN
				SET @UpdCurency = 1
			END
			WHILE (EXISTS(SELECT TOP 1 1  FROM #Agent WHERE STT = @row_STT ))
			BEGIN
				SELECT @SMAs = '', @ids = ''
				SELECT @Recommend = CustID, @Subsidiary = Subsidiary FROM #Agent WHERE STT = @row_STT

				INSERT INTO #SportTypeBetType_History (SportType, Bettype, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch )
				SELECT cs.SportType, cs.BetType, cs.MinBet, cs.MaxBet, cs.MaxPerMatch, cs.MaxPerNumber, cs.MaxPayoutPerMatch  
				FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
				WHERE cs.CustID = @Recommend

				IF @row_STT = 1
				BEGIN
					SET @SMAs = (SELECT STRING_AGG(CONVERT(VARCHAR(MAX),custid),',')  FROM #temp WHERE roleid IN (3,4))
				END
				ELSE
				BEGIN
					SET @SMAs = ''
				END

				WHILE (1 = 1)
				BEGIN
					SELECT @ids = ''
					UPDATE TOP (9900) #temp
					SET isfinished = 1
					OUTPUT INSERTED.CustID INTO #tmpCustTemp(CustID)	
					FROM #temp 
					WHERE isfinished = 0 AND recommend = @Recommend

					SELECT @rowcnt = @@ROWCOUNT	
					SET @ids = (SELECT STRING_AGG(CONVERT(VARCHAR(MAX),custid),',')  FROM #tmpCustTemp)
					SET @ids = ISNULL(@SMAs,'') + ',' + @ids

					EXEC Acc_CustSetting3rd_11
						@ids = @ids, 
						@srecommend = @CustID, 
						@UpdBetLimit = @UpdBetLimit, 
						@ExistedMember = @ExistedMember, 
						@UpdCurency = @UpdCurency,
						@Option = @Option,
						@Mode = 'Sportbook' 

					SET @SMAs = ''
					TRUNCATE TABLE #tmpCustTemp
					IF @rowcnt < 9900 BREAK
				END
				SET @row_STT +=1
				-- Log new updated data
				SET @xml = (
						SELECT	@UserID								AS '@UserID',				
								@IP									AS '@IP',
								@Site								AS '@Licensee',
								@Currency							AS '@Currency',
								@CurrencyID							AS '@CurrencyID',
								@Subsidiary							AS '@Subsidiary',
								@Language							AS '@Language',
								@Option								AS '@Option',
								CASE WHEN @ExistedMember = 1 THEN 'Yes' ELSE 'No' END	AS '@ExistingPlayers',
								CASE WHEN @IsNewMember = 1 THEN 'Yes' ELSE 'No' END	 	AS '@NewPlayers',
								COALESCE(CAST(@ErrMsg				AS VARCHAR(400)),SPACE(1))	AS '@ErrMsg',
								COALESCE(CAST(@ErrCode				AS VARCHAR(50)),SPACE(1))	AS '@ErrCode',
								(
									SELECT  COALESCE(CAST(SportType AS VARCHAR(50)), SPACE(1))	AS '@SportType',
										COALESCE(CAST(Bettype AS VARCHAR(50)), SPACE(1))	AS '@Bettype',
										COALESCE(CAST(MinBet AS VARCHAR(50)), SPACE(1))	AS '@MinBet',
										COALESCE(CAST(MaxBet AS VARCHAR(50)), SPACE(1))	AS '@MaxBet',
										COALESCE(CAST(MaxPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPerMatch',
										COALESCE(CAST(MaxPayoutPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPayoutPerMatch'
									FROM	#SportTypeBetType_History
									ORDER BY SportType, Bettype
									FOR XML PATH('BL'), 
									TYPE
								)
						FOR XML PATH('R'),
						TYPE
					)
				SET @logSpData_Old = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
				SET @xml = (
						SELECT	@UserID								AS '@UserID',				
								@IP									AS '@IP',
								@Site								AS '@Licensee',
								@Currency							AS '@Currency',
								@CurrencyID							AS '@CurrencyID',
								@Subsidiary							AS '@Subsidiary',
								@Language							AS '@Language',
								@Option								AS '@Option',
								CASE WHEN @ExistedMember = 1 THEN 'Yes' ELSE 'No' END	AS '@ExistingPlayers',
								CASE WHEN @IsNewMember = 1 THEN 'Yes' ELSE 'No' END	 	AS '@NewPlayers',
								COALESCE(CAST(@ErrMsg				AS VARCHAR(400)),SPACE(1))	AS '@ErrMsg',
								COALESCE(CAST(@ErrCode				AS VARCHAR(50)),SPACE(1))	AS '@ErrCode',
								( 
									SELECT  COALESCE(CAST(SportType AS VARCHAR(50)), SPACE(1))	AS '@SportType',
										COALESCE(CAST(Bettype AS VARCHAR(50)), SPACE(1))	AS '@Bettype',
										COALESCE(CAST(MinBet AS VARCHAR(50)), SPACE(1))	AS '@MinBet',
										COALESCE(CAST(MaxBet AS VARCHAR(50)), SPACE(1))	AS '@MaxBet',
										COALESCE(CAST(MaxPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPerMatch',
										COALESCE(CAST(MaxPayoutPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPayoutPerMatch'
									FROM	#SportTypeBetType
									ORDER BY SportType, Bettype
									FOR XML PATH('BL'), 
									TYPE
								)
						FOR XML PATH('R'),
						TYPE
					)
				SET @logSpData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

				SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

				EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper    
						  @UserID = @UserID,    
						  @CustID = @Recommend,    
						  @ActionID = @ActionID,    
						  @TrackingValue = @LogSPData,
						  @TrackingValue2 = @logSpData_Old,
						  @duration = @duration    	
			
				TRUNCATE TABLE #SportTypeBetType_History
			END		
		END TRY
		BEGIN CATCH
			SELECT @ErrMsg = ERROR_MESSAGE(), @ErrCode  = ERROR_NUMBER()   					
			RETURN
		END CATCH
	END

	IF @ProductID = 1
		AND NOT EXISTS (SELECT 1 FROM Dep_ProductSetting ps WITH(NOLOCK) 
							INNER JOIN Dep_LicenseeProductSetting d WITH(NOLOCK) ON ps.ProductSettingID=d.ProductSettingID WHERE ProductID=@ProductID AND CustID = @CustID AND SettingType <> 9)	
	BEGIN
		INSERT INTO Dep_LicenseeProductSetting(CustID,ProductSettingID)
		SELECT @CustID, ProductSettingID
		FROM Dep_ProductSetting WITH(NOLOCK)
		WHERE ProductID = @ProductID AND SettingType <> 9
	END
	  
	IF @ProductID <> 1
		AND NOT EXISTS (SELECT 1 FROM Dep_ProductSetting ps WITH(NOLOCK) 
							INNER JOIN Dep_LicenseeProductSetting d WITH(NOLOCK) ON ps.ProductSettingID=d.ProductSettingID WHERE ProductID=@ProductID AND CustID = @CustID)	
	BEGIN
		INSERT INTO Dep_LicenseeProductSetting(CustID,ProductSettingID)
		SELECT @CustID, ProductSettingID
		FROM Dep_ProductSetting WITH(NOLOCK)
		WHERE ProductID = @ProductID
	END

	IF NOT EXISTS (SELECT 1 FROM Dep_ProductSetting ps WITH(NOLOCK) 
							INNER JOIN Dep_LicenseeProductSetting d WITH(NOLOCK) ON ps.ProductSettingID=d.ProductSettingID WHERE ProductID=@ProductID AND CustID = @CustID)
	BEGIN
		INSERT INTO Dep_LicenseeProductSetting(CustID,ProductSettingID)
		SELECT @CustID, ProductSettingID
		FROM Dep_ProductSetting WITH(NOLOCK)
		WHERE ProductID = @ProductID
	END	
	IF NOT EXISTS(SELECT TOP 1 1 FROM #NewDefault)
	BEGIN
		INSERT INTO #NewDefault (SportType, Bettype, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch )
		SELECT SportType, Bettype, MinBet, MaxBet, MaxPerMatch, MaxPerNumber, MaxPayoutPerMatch
		FROM #SportTypeBetType

		SET @IsNotDBS = 1
	END
	-- Defaut bet limit
	IF @Option = 0
	BEGIN
		-- Currency only OR Subsidiary only
		IF  @IsNewMember = 0 AND @ExistedMember = 0 AND @IsNotDBS = 0
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
			FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
				INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
			WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site  
				AND 1 = CASE WHEN @AgentID = 0 AND d.AgentID IS NULL THEN 1 
							 WHEN @AgentID <> 0 AND  d.AgentID = @AgentID THEN 1 ELSE 0 END)
			BEGIN
				UPDATE d 
				SET d.MinBet = s.MinBet,
					d.MaxBet = s.MaxBet,
					d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
					d.MaxPerMatch = s.MaxPerMatch
				OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch ,1 AS UplineUpdate  	
				INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch,UplineUpdate)
				FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
					INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
				WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND 1 = CASE WHEN @AgentID = 0 AND d.AgentID IS NULL THEN 1 
																				 WHEN @AgentID <> 0 AND  d.AgentID = @AgentID THEN 1 ELSE 0 END
			END
			ELSE 
			BEGIN
				INSERT INTO Dep_CustBetLimit_Special([Site], CurrencyID, SportType, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPerBall, MaxPayoutPerMatch, Bettype)
				SELECT @Site, @CurrencyID, SportType, CASE WHEN @AgentID = 0 THEN NULL ELSE @AgentID END AS AgentID, MinBet, MaxBet, MaxPerMatch, NULL AS MaxPerBall, MaxPayoutPerMatch, Bettype 
				FROM #NewDefault n
				UNION 
				SELECT @Site, @CurrencyID, SportType, CASE WHEN @AgentID = 0 THEN NULL ELSE @AgentID END AS AgentID, NULL AS MinBet, NULL AS  MaxBet, NULL AS  MaxPerMatch, NULL AS MaxPerBall, NULL AS  MaxPayoutPerMatch, Bettype
				FROM #SportBettypeFilter d
				WHERE ProductID = 1 AND NOT EXISTS (SELECT TOP 1 1 FROM #NewDefault WHERE  SportType = d.SportType AND BetType = d.Bettype)
				
				INSERT INTO #AgentLog(custid) SELECT CASE WHEN @AgentID = 0 THEN -1 ELSE @AgentID END AS AgentID 
				SET @ActionDefaultID = 13
			END

		END
		ELSE IF @AgentID = 0 AND @IsNewMember = 1 -- Currency + All player OR Currency + New player
		BEGIN
			UPDATE d 
			SET d.MinBet = NULL,
				d.MaxBet = NULL,
				d.MaxPayoutPerMatch = NULL,
				d.MaxPerMatch = NULL
			OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch, 14 AS ActionDefaultID   	
			INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch,ActionDefaultID)
			FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
				INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
			WHERE [Site] = @Site AND CurrencyID = @CurrencyID  AND (AgentID IS NULL OR AgentID IN (SELECT custid FROM #Agent) )
			
			DELETE dbs  
			FROM Dep_CustBetLimit_Special dbs WITH(ROWLOCK,UPDLOCK)
			WHERE dbs.Site = @Site AND CurrencyID = @CurrencyID 
			AND (AgentID IS NULL OR AgentID IN (SELECT custid FROM #Agent) )
			AND NOT EXISTS (SELECT TOP 1 1 
						FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
							INNER JOIN #SportBettypeFilter s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
						WHERE d.CurrencyID = dbs.CurrencyID AND d.Site = dbs.Site AND ISNULL(d.AgentID,-1) =  ISNULL(dbs.AgentID,-1)
							AND (d.MinBet IS NOT NULL OR d.MaxBet IS NOT NULL OR d.MaxPerMatch IS NOT NULL OR d.MaxPayoutPerMatch IS NOT NULL))
			
		END
		ELSE IF @AgentID <> 0 AND @IsNewMember = 1 --Subsidiary + All player OR Subsidiary + New player
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
				FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
					INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
				WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND AgentID = @AgentID) 
			BEGIN
				IF EXISTS (SELECT TOP 1 1 
						FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
							INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
						WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND AgentID IS NULL)
				BEGIN
					IF @IsNotDBS = 0
					BEGIN
						UPDATE d 
						SET d.MinBet = s.MinBet,
							d.MaxBet = s.MaxBet,
							d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
							d.MaxPerMatch = s.MaxPerMatch
						OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch,1 AS UplineUpdate   	
						INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch,UplineUpdate)
						FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
							INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
						WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND d.AgentID IS NULL
					END

					UPDATE d 
					SET d.MinBet = s.MinBet,
						d.MaxBet = s.MaxBet,
						d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
						d.MaxPerMatch = s.MaxPerMatch
					OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch   	
					INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch)
					FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
						INNER JOIN #SportTypeBetType s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
					WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND d.AgentID = @AgentID
				END
				ELSE
				BEGIN
					UPDATE d 
					SET d.MinBet = NULL,
						d.MaxBet = NULL,
						d.MaxPayoutPerMatch = NULL,
						d.MaxPerMatch = NULL
					OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch , 14 AS ActionDefaultID  	
					INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch,ActionDefaultID)
					FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
						INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
					WHERE [Site] = @Site AND CurrencyID = @CurrencyID  AND d.AgentID = @AgentID

					DELETE dbs  
					FROM Dep_CustBetLimit_Special dbs WITH(ROWLOCK,UPDLOCK)
					WHERE dbs.Site = @Site AND CurrencyID = @CurrencyID 
					AND dbs.AgentID = @AgentID
					AND NOT EXISTS (SELECT TOP 1 1 
								FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
									INNER JOIN #SportBettypeFilter s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
								WHERE d.CurrencyID = dbs.CurrencyID AND d.Site = dbs.Site AND ISNULL(d.AgentID,-1) =  ISNULL(dbs.AgentID,-1)
									AND (d.MinBet IS NOT NULL OR d.MaxBet IS NOT NULL OR d.MaxPerMatch IS NOT NULL OR d.MaxPayoutPerMatch IS NOT NULL))
				END
			END
			ELSE
			BEGIN
				IF EXISTS (SELECT TOP 1 1 
						FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
							INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
						WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND AgentID IS NULL)
				BEGIN
					IF @IsNotDBS = 0
					BEGIN
						UPDATE d 
						SET d.MinBet = s.MinBet,
							d.MaxBet = s.MaxBet,
							d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
							d.MaxPerMatch = s.MaxPerMatch
						OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch,1 AS UplineUpdate   	
						INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch,UplineUpdate)
						FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
							INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
						WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND d.AgentID IS NULL
					END

					INSERT INTO Dep_CustBetLimit_Special([Site], CurrencyID, SportType, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPerBall, MaxPayoutPerMatch, Bettype)
					SELECT @Site, @CurrencyID, SportType, @AgentID, MinBet, MaxBet, MaxPerMatch, NULL AS MaxPerBall, MaxPayoutPerMatch, Bettype 
					FROM #SportTypeBetType
					UNION 
					SELECT @Site, @CurrencyID, SportType, @AgentID, NULL AS MinBet, NULL AS  MaxBet, NULL AS  MaxPerMatch, NULL AS MaxPerBall, NULL AS  MaxPayoutPerMatch, Bettype
					FROM #SportBettypeFilter d
					WHERE ProductID = 1 AND NOT EXISTS (SELECT TOP 1 1 FROM #SportTypeBetType WHERE  SportType = d.SportType AND BetType = d.Bettype)
				
					INSERT INTO #AgentLog(custid, UplineUpdate) SELECT @AgentID, 1
					SET @ActionDefaultID = 13
				END
			END
		END
	END
	ELSE
	BEGIN
		IF @AgentID = 0 AND @IsNewMember = 1 AND @ExistedMember = 1 --All player - Existing + New player (All Subsidiary)
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
					  FROM Dep_CustBetLimit_Special cs WITH(NOLOCK)
						INNER JOIN #NewDefault s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype	
					 WHERE cs.CurrencyID = @CurrencyID AND cs.Site = @Site
						AND AgentID IN (SELECT custid FROM #Agent))
			BEGIN
				UPDATE d 
				SET d.MinBet = NULL,
					d.MaxBet = NULL,
					d.MaxPayoutPerMatch = NULL,
					d.MaxPerMatch = NULL
				OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch , 14 AS ActionDefaultID  	
				INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch,ActionDefaultID)
				FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
					INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
				WHERE [Site] = @Site AND CurrencyID = @CurrencyID  AND d.AgentID IN (SELECT custid FROM #Agent)

				DELETE dbs  
				FROM Dep_CustBetLimit_Special dbs WITH(ROWLOCK,UPDLOCK)
				WHERE dbs.Site = @Site AND CurrencyID = @CurrencyID 
				AND dbs.AgentID IN (SELECT custid FROM #Agent)
				AND NOT EXISTS (SELECT TOP 1 1 
							FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
								INNER JOIN #SportBettypeFilter s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
							WHERE d.CurrencyID = dbs.CurrencyID AND d.Site = dbs.Site AND ISNULL(d.AgentID,-1) =  ISNULL(dbs.AgentID,-1)
								AND (d.MinBet IS NOT NULL OR d.MaxBet IS NOT NULL OR d.MaxPerMatch IS NOT NULL OR d.MaxPayoutPerMatch IS NOT NULL))
			END
			IF EXISTS (SELECT TOP 1 1 
			FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
				INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
			WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND AgentID IS NULL)
			BEGIN
				UPDATE d 
				SET d.MinBet = s.MinBet,
					d.MaxBet = s.MaxBet,
					d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
					d.MaxPerMatch = s.MaxPerMatch
				OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch   	
				INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch)
				FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
					INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
				WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND d.AgentID IS NULL
			END
			ELSE 
			BEGIN
				INSERT INTO Dep_CustBetLimit_Special([Site], CurrencyID, SportType, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPerBall, MaxPayoutPerMatch, Bettype)
				SELECT @Site, @CurrencyID, SportType, NULL AS AgentID, MinBet, MaxBet, MaxPerMatch, NULL AS MaxPerBall, MaxPayoutPerMatch, Bettype 
				FROM #NewDefault n
				UNION 
				SELECT @Site, @CurrencyID, SportType, NULL AS AgentID, NULL AS MinBet, NULL AS  MaxBet, NULL AS  MaxPerMatch, NULL AS MaxPerBall, NULL AS  MaxPayoutPerMatch, Bettype
				FROM #SportBettypeFilter d
				WHERE ProductID = 1 AND NOT EXISTS (SELECT TOP 1 1 FROM #NewDefault WHERE  SportType = d.SportType AND BetType = d.Bettype)
				
				INSERT INTO #AgentLog(custid) SELECT -1 AS AgentID 
				SET @ActionDefaultID = 13
			END
		END
		ELSE IF @AgentID <> 0 AND @IsNewMember = 1 AND @ExistedMember = 1 --All player - Existing + New player (Specific Subsidiary)
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
					FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
						INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
					WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND AgentID IS NULL)
			
			BEGIN
				IF @IsNotDBS = 0
				BEGIN
					UPDATE d 
					SET d.MinBet = s.MinBet,
						d.MaxBet = s.MaxBet,
						d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
						d.MaxPerMatch = s.MaxPerMatch
					OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch,1 AS UplineUpdate   	
					INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch,UplineUpdate)
					FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
						INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
					WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND d.AgentID IS NULL
				END 

				IF EXISTS (SELECT TOP 1 1 
					FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
						INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
					WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND AgentID = @AgentID)
					BEGIN 

						UPDATE d 
						SET d.MinBet = s.MinBet,
							d.MaxBet = s.MaxBet,
							d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
							d.MaxPerMatch = s.MaxPerMatch
						OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch   	
						INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch)
						FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
							INNER JOIN #SportTypeBetType s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
						WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND d.AgentID = @AgentID
					END
					ELSE
					BEGIN
						INSERT INTO Dep_CustBetLimit_Special([Site], CurrencyID, SportType, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPerBall, MaxPayoutPerMatch, Bettype)
						SELECT @Site, @CurrencyID, SportType, @AgentID AS AgentID, MinBet, MaxBet, MaxPerMatch, NULL AS MaxPerBall, MaxPayoutPerMatch, Bettype 
						FROM #SportTypeBetType
						UNION 
						SELECT @Site, @CurrencyID, SportType, @AgentID, NULL AS MinBet, NULL AS  MaxBet, NULL AS  MaxPerMatch, NULL AS MaxPerBall, NULL AS  MaxPayoutPerMatch, Bettype
						FROM #SportBettypeFilter d
						WHERE ProductID = 1 AND NOT EXISTS (SELECT TOP 1 1 FROM #SportTypeBetType WHERE  SportType = d.SportType AND BetType = d.Bettype)
					
						INSERT INTO #AgentLog(custid, UplineUpdate) SELECT @AgentID , 1 AS UplineUpdate
						SET @ActionDefaultID = 13
					END
			END
			ELSE
			BEGIN
				IF EXISTS (SELECT TOP 1 1 
					FROM Dep_CustBetLimit_Special d WITH(NOLOCK)
						INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
					WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND AgentID = @AgentID)
					BEGIN
						UPDATE d 
						SET d.MinBet = s.MinBet,
							d.MaxBet = s.MaxBet,
							d.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
							d.MaxPerMatch = s.MaxPerMatch
						OUTPUT	s.SportType, s.Bettype, deleted.AgentID, deleted.MinBet, deleted.MaxBet, deleted.MaxPerMatch, deleted.MaxPayoutPerMatch   	
						INTO #NewDefault_History(SportType, Bettype, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPayoutPerMatch)
						FROM Dep_CustBetLimit_Special d WITH(UPDLOCK)
							INNER JOIN #NewDefault s ON d.SportType = s.SportType AND d.BetType = s.Bettype	
						WHERE d.CurrencyID = @CurrencyID AND d.Site = @Site AND d.AgentID = @AgentID
					END
					ELSE
					BEGIN
						INSERT INTO Dep_CustBetLimit_Special([Site], CurrencyID, SportType, AgentID, MinBet, MaxBet, MaxPerMatch, MaxPerBall, MaxPayoutPerMatch, Bettype)
						SELECT @Site, @CurrencyID, SportType, @AgentID AS AgentID, MinBet, MaxBet, MaxPerMatch, NULL AS MaxPerBall, MaxPayoutPerMatch, Bettype 
						FROM #SportTypeBetType
						UNION 
						SELECT @Site, @CurrencyID, SportType, @AgentID, NULL AS MinBet, NULL AS  MaxBet, NULL AS  MaxPerMatch, NULL AS MaxPerBall, NULL AS  MaxPayoutPerMatch, Bettype
						FROM #SportBettypeFilter d
						WHERE ProductID = 1 AND NOT EXISTS (SELECT TOP 1 1 FROM #SportTypeBetType WHERE  SportType = d.SportType AND BetType = d.Bettype)
					
						INSERT INTO #AgentLog(custid, UplineUpdate) SELECT @AgentID , 1 AS UplineUpdate
						SET @ActionDefaultID = 13
					END
			END
		END
	END

	-- Log new Default data
	IF @ActionDefaultID = 13
	BEGIN
		DELETE b FROM #AgentLog a INNER JOIN #AgentLog b ON a.custid = b.custid AND b.STT > a.STT
		WHILE (1 = 1)
		BEGIN
			UPDATE TOP (1) a
			SET a.isfinished = 1,
				@AgentID = a.custid,
				@UplineUpdate = UplineUpdate
			FROM #AgentLog a	
			WHERE isfinished = 0 

			IF @@ROWCOUNT = 0 BREAK
			
			IF	@AgentID > 0
			BEGIN
				SELECT @Subsidiary  = Subsidiary FROM #Agent WHERE custid = @AgentID
			END
			ELSE
			BEGIN
				SELECT @Subsidiary = '' , @AgentID = null
			END
			IF @UplineUpdate = 1
			BEGIN
				-- Log new Default data
				SET @xml = (
						SELECT	@UserID								AS '@UserID',				
								@IP									AS '@IP',
								@Site								AS '@Licensee',
								@Currency							AS '@Currency',
								@CurrencyID							AS '@CurrencyID',
								@Subsidiary							AS '@Subsidiary',
								@Language							AS '@Language',
								@Option								AS '@Option',
								COALESCE(CAST(@ErrMsg				AS VARCHAR(400)),SPACE(1))	AS '@ErrMsg',
								COALESCE(CAST(@ErrCode				AS VARCHAR(50)),SPACE(1))	AS '@ErrCode',
								(
									SELECT  COALESCE(CAST(SportType AS VARCHAR(50)), SPACE(1))	AS '@SportType',
											COALESCE(CAST(Bettype AS VARCHAR(50)), SPACE(1))	AS '@Bettype',
											COALESCE(CAST(MinBet AS VARCHAR(50)), SPACE(1))	AS '@MinBet',
											COALESCE(CAST(MaxBet AS VARCHAR(50)), SPACE(1))	AS '@MaxBet',
											COALESCE(CAST(MaxPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPerMatch',
											COALESCE(CAST(MaxPayoutPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPayoutPerMatch'
									FROM	#SportTypeBetType
									ORDER BY SportType, Bettype
									FOR XML PATH('BL'), 
									TYPE
								)
						FOR XML PATH('R'),
						TYPE
					)
			END
			ELSE
			BEGIN
				-- Log new Default data
				SET @xml = (
						SELECT	@UserID								AS '@UserID',				
								@IP									AS '@IP',
								@Site								AS '@Licensee',
								@Currency							AS '@Currency',
								@CurrencyID							AS '@CurrencyID',
								@Subsidiary							AS '@Subsidiary',
								@Language							AS '@Language',
								@Option								AS '@Option',
								COALESCE(CAST(@ErrMsg				AS VARCHAR(400)),SPACE(1))	AS '@ErrMsg',
								COALESCE(CAST(@ErrCode				AS VARCHAR(50)),SPACE(1))	AS '@ErrCode',
								(
									SELECT  COALESCE(CAST(SportType AS VARCHAR(50)), SPACE(1))	AS '@SportType',
											COALESCE(CAST(Bettype AS VARCHAR(50)), SPACE(1))	AS '@Bettype',
											COALESCE(CAST(MinBet AS VARCHAR(50)), SPACE(1))	AS '@MinBet',
											COALESCE(CAST(MaxBet AS VARCHAR(50)), SPACE(1))	AS '@MaxBet',
											COALESCE(CAST(MaxPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPerMatch',
											COALESCE(CAST(MaxPayoutPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPayoutPerMatch'
									FROM	#NewDefault
									ORDER BY SportType, Bettype
									FOR XML PATH('BL'), 
									TYPE
								)
						FOR XML PATH('R'),
						TYPE
					)
			END

			SET @logSpData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

			SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

			EXEC DBLOG.bodb_customerlog.dbo.NAP_SpecialCustSetting_WriteLog
						@UserId = @UserID,
						@IP = @IP,
						@LicenseeID = @LicenseeID,
						@CurrencyID = @CurrencyID,
						@SPName = 'NAP_LM_LicenseeBetLimitUpd',
						@CustId = @AgentId,
						@ActionId = @ActionDefaultID,
						@Duration = @Duration,
						@Data = @logSpData,
						@OldData = NULL
		 END
	END

	IF EXISTS (SELECT TOP 1 1 FROM #NewDefault_History cs) 
	BEGIN
		SET @UplineUpdate = 0
		WHILE (1 = 1)
		BEGIN
			UPDATE TOP (1) a
			SET a.isfinished = 1,
				@AgentID = a.AgentID,
				@ActionDefaultID =  a.ActionDefaultID,
				@UplineUpdate = UplineUpdate
			FROM #NewDefault_History a	
			WHERE isfinished = 0 

			IF @@ROWCOUNT = 0 BREAK

			UPDATE a
			SET a.isfinished = 1
			FROM #NewDefault_History a	
			WHERE isfinished = 0 AND a.AgentID = @AgentID

			IF	@AgentID > 0
			BEGIN
				SELECT @Subsidiary  = Subsidiary FROM #Agent WHERE custid = @AgentID
			END
			ELSE
			BEGIN
				SELECT @Subsidiary = '' , @AgentID = null
			END
			-- Log new Default data
			SET @xml = (
					SELECT	@UserID								AS '@UserID',				
							@IP									AS '@IP',
							@Site								AS '@Licensee',
							@Currency							AS '@Currency',
							@CurrencyID							AS '@CurrencyID',
							@Subsidiary							AS '@Subsidiary',
							@Language							AS '@Language',
							@Option								AS '@Option',
							COALESCE(CAST(@ErrMsg				AS VARCHAR(400)),SPACE(1))	AS '@ErrMsg',
							COALESCE(CAST(@ErrCode				AS VARCHAR(50)),SPACE(1))	AS '@ErrCode',
							(
								SELECT  COALESCE(CAST(SportType AS VARCHAR(50)), SPACE(1))	AS '@SportType',
										COALESCE(CAST(Bettype AS VARCHAR(50)), SPACE(1))	AS '@Bettype',
										COALESCE(CAST(MinBet AS VARCHAR(50)), SPACE(1))	AS '@MinBet',
										COALESCE(CAST(MaxBet AS VARCHAR(50)), SPACE(1))	AS '@MaxBet',
										COALESCE(CAST(MaxPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPerMatch',
										COALESCE(CAST(MaxPayoutPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPayoutPerMatch'
								FROM	#NewDefault_History
								WHERE ((AgentID = @AgentID AND @AgentID IS NOT NULL) OR (AgentID IS NULL AND @AgentID IS NULL))
								ORDER BY SportType, Bettype
								FOR XML PATH('BL'), 
								TYPE
							)
					FOR XML PATH('R'),
					TYPE
				)
			SET @logSpData_Old = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
			IF @UplineUpdate = 1 
			BEGIN
				SET @xml = (
						SELECT	@UserID								AS '@UserID',				
								@IP									AS '@IP',
								@Site								AS '@Licensee',
								@Currency							AS '@Currency',
								@CurrencyID							AS '@CurrencyID',
								@Subsidiary							AS '@Subsidiary',
								@Language							AS '@Language',
								@Option								AS '@Option',
								COALESCE(CAST(@ErrMsg				AS VARCHAR(400)),SPACE(1))	AS '@ErrMsg',
								COALESCE(CAST(@ErrCode				AS VARCHAR(50)),SPACE(1))	AS '@ErrCode',
								(
									SELECT  COALESCE(CAST(SportType AS VARCHAR(50)), SPACE(1))	AS '@SportType',
											COALESCE(CAST(Bettype AS VARCHAR(50)), SPACE(1))	AS '@Bettype',
											COALESCE(CAST(MinBet AS VARCHAR(50)), SPACE(1))	AS '@MinBet',
											COALESCE(CAST(MaxBet AS VARCHAR(50)), SPACE(1))	AS '@MaxBet',
											COALESCE(CAST(MaxPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPerMatch',
											COALESCE(CAST(MaxPayoutPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPayoutPerMatch'
									FROM	#NewDefault
									ORDER BY SportType, Bettype
									FOR XML PATH('BL'), 
									TYPE
								)
						WHERE @ActionDefaultID = 12
						FOR XML PATH('R'),
						TYPE
					)
			END
			ELSE
			BEGIN
				SET @xml = (
						SELECT	@UserID								AS '@UserID',				
								@IP									AS '@IP',
								@Site								AS '@Licensee',
								@Currency							AS '@Currency',
								@CurrencyID							AS '@CurrencyID',
								@Subsidiary							AS '@Subsidiary',
								@Language							AS '@Language',
								@Option								AS '@Option',
								COALESCE(CAST(@ErrMsg				AS VARCHAR(400)),SPACE(1))	AS '@ErrMsg',
								COALESCE(CAST(@ErrCode				AS VARCHAR(50)),SPACE(1))	AS '@ErrCode',
								(
									SELECT  COALESCE(CAST(SportType AS VARCHAR(50)), SPACE(1))	AS '@SportType',
											COALESCE(CAST(Bettype AS VARCHAR(50)), SPACE(1))	AS '@Bettype',
											COALESCE(CAST(MinBet AS VARCHAR(50)), SPACE(1))	AS '@MinBet',
											COALESCE(CAST(MaxBet AS VARCHAR(50)), SPACE(1))	AS '@MaxBet',
											COALESCE(CAST(MaxPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPerMatch',
											COALESCE(CAST(MaxPayoutPerMatch AS VARCHAR(50)), SPACE(1)) AS '@MaxPayoutPerMatch'
									FROM	#SportTypeBetType
									ORDER BY SportType, Bettype
									FOR XML PATH('BL'), 
									TYPE
								)
						WHERE @ActionDefaultID = 12
						FOR XML PATH('R'),
						TYPE
					)
			END
			SET @logSpData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

			SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

			EXEC DBLOG.bodb_customerlog.dbo.NAP_SpecialCustSetting_WriteLog
						@UserId = @UserID,
						@IP = @IP,
						@LicenseeID = @LicenseeID,
						@CurrencyID = @CurrencyID,
						@SPName = 'NAP_LM_LicenseeBetLimitUpd',
						@CustId = @AgentId,
						@ActionId = @ActionDefaultID,
						@Duration = @Duration,
						@Data = @logSpData,
						@OldData = @logSpData_Old
		 END
	END
 END
 
 