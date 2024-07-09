/*<info serverAlias="DBCUST-CustDB" executers="wsv_alp,wsv_nap,wsv_xnap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_CustSetting_BetLimitUpd]
	@ids VARCHAR(MAX)
	,@srecommend INT
	,@Sporttype INT = 0
	,@Bettype INT = 0
	,@MinBet MONEY=0
	,@MaxBet MONEY=0
	,@MaxPerMatch MONEY=0
	,@MaxPerBall MONEY = 0
	,@MaxPayoutPerMatch MONEY = 0
	,@ExistedMember BIT
	,@UpdateMinBet BIT = 0
	,@UpdateMaxBet BIT = 0
	,@UpdateMPM BIT = 0
	,@UpdateMaxPayoutPM BIT = 0
	,@Enable BIT = 0 
	,@EnableDownline BIT = 0
	,@UpdBetLimit	VARCHAR(MAX) = NULL
	,@UpdCurency BIT = 0
	,@Option BIT = 0
	,@Mode		VARCHAR(20) = 'NonSportbook'
AS
/*
	Created: 20240708@Johnson	
	Task : Licensee Setting Configuration - Update Bet Setting [#6304]
	DB: DBCUST/CustDB
	Original:Acc_CustSetting3rd_11

	Revisions:
		- 20240708@Johnson: Apply In-house Replication for Customer Setting [redmine:#207025]	
	Param's Explanation:
		
*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ProductID TINYINT
	CREATE TABLE #SportBettypeFilter (ProductID TINYINT, Sporttype SMALLINT, Bettype SMALLINT, IsLive BIT, SettingType TINYINT)
	
	IF @Mode <> 'Sportbook'
	BEGIN
		SELECT @ProductID = CASE	WHEN @Sporttype IN (1,2,3,5,8,10,11,99,9901,9902,43,50,9907) THEN 1 
									WHEN @Sporttype = 161 THEN 3
									WHEN @Sporttype = 202 THEN 8 END	

		INSERT INTO #SportBettypeFilter (ProductID,SportType,Bettype,IsLive,SettingType)
		SELECT @ProductID AS ProductID,SportType,Bettype,IsLive, SettingType 
		FROM dbo.f_Dep_CustSetting_SportBetTypeSettingSelect(@ProductID,NULL)

		DECLARE @string VARCHAR(MAX), @splitter CHAR(1), @xml XML
		SELECT @splitter = ',', @string = @ids

		SET @xml = N'<root><r i=''' + REPLACE(@string, @splitter, '''/><r i=''') + '''/></root>'

		--Create temp table containing all accounts belong to super, exclude fincance account
		CREATE TABLE #tblCust (custid INT)	
		INSERT INTO #tblCust(custid)
		SELECT r.value('./@i','INT')
		FROM @xml.nodes('//root/r') AS RECORDS(r)

		IF @Sporttype IN (1,2,3,5,8,10,11,99,9901,9902,43,50,9907) --Sportbook
			BEGIN	
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET cs.minbet = CASE WHEN @UpdateMinBet = 1 THEN @MinBet ELSE cs.MinBet END, 
					cs.maxbet = CASE WHEN @UpdateMaxBet = 1 THEN @maxbet ELSE cs.MaxBet END,
					cs.MaxPerMatch = CASE WHEN @UpdateMPM = 1 THEN @MaxPerMatch ELSE cs.MaxPerMatch END, 
					cs.MaxPayoutPerMatch = CASE WHEN @UpdateMaxPayoutPM = 1 THEN @MaxPayoutPerMatch ELSE cs.MaxPayoutPerMatch END,
					cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGame_Agent cs
					INNER JOIN CustInfo c ON c.custid = cs.custid
				WHERE cs.Sporttype = @Sporttype
					AND cs.bettype = @Bettype
					AND c.custid IN (SELECT custid FROM #tblCust)
					AND roleid BETWEEN 2 AND 4

				IF @ExistedMember = 1
				BEGIN
					UPDATE cs WITH(UPDLOCK,ROWLOCK)
					SET cs.minbet = CASE WHEN @UpdateMinBet = 1 THEN @MinBet ELSE cs.MinBet END, 
						cs.maxbet = CASE WHEN @UpdateMaxBet = 1 THEN @maxbet ELSE cs.MaxBet END,
						cs.MaxPerMatch = CASE WHEN @UpdateMPM = 1 THEN @MaxPerMatch ELSE cs.MaxPerMatch END, 
						cs.MaxPayoutPerMatch = CASE WHEN @UpdateMaxPayoutPM = 1 THEN @MaxPayoutPerMatch ELSE cs.MaxPayoutPerMatch END,
						cs.RepUpdateTime = SYSDATETIME()
					FROM dbo.Dep_CustBetSettingGameGroup_Member cs
						INNER JOIN CustInfo c ON c.custid = cs.AgentID
					WHERE cs.Sporttype = @Sporttype
						AND cs.bettype = @Bettype
						AND c.custid IN (SELECT custid FROM #tblCust)
						AND roleid = 2

					UPDATE cs WITH(UPDLOCK,ROWLOCK)
					SET cs.minbet = CASE WHEN @UpdateMinBet = 1 THEN @MinBet ELSE cs.MinBet END, 
						cs.maxbet = CASE WHEN @UpdateMaxBet = 1 THEN @maxbet ELSE cs.MaxBet END,
						cs.MaxPerMatch = CASE WHEN @UpdateMPM = 1 THEN @MaxPerMatch ELSE cs.MaxPerMatch END, 
						cs.MaxPayoutPerMatch = CASE WHEN @UpdateMaxPayoutPM = 1 THEN @MaxPayoutPerMatch ELSE cs.MaxPayoutPerMatch END,
						cs.RepUpdateTime = SYSDATETIME()
					FROM dbo.Dep_CustBetSettingGame_Member cs
						INNER JOIN CustInfo c ON c.custid = cs.custid
					WHERE cs.Sporttype = @Sporttype
						AND cs.bettype = @Bettype
						AND c.custid IN (SELECT custid FROM #tblCust)
						AND roleid = 1
				END

				DELETE t 
				FROM #tblCust t 
				INNER JOIN Dep_CustBetSettingGame_Agent cs on t.custid = cs.custid AND cs.sporttype = @Sporttype AND bettype = @Bettype
				DELETE t 
				FROM #tblCust t 
				INNER JOIN Dep_CustBetSettingGameGroup_Member cs on t.custid = cs.AgentID AND cs.sporttype = @Sporttype AND bettype = @Bettype
				DELETE t 
				FROM #tblCust t 
				INNER JOIN Dep_CustBetSettingGame_Member cs on t.custid = cs.custid AND cs.sporttype = @Sporttype AND bettype = @Bettype
	 
				INSERT INTO Dep_CustBetSettingGame_Agent ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
				SELECT  t.custid			   
					   ,sporttype as [sporttype]
					   ,bettype as [bettype]
					   ,CASE WHEN @UpdateMinBet = 1 THEN @MinBet 
							ELSE (SELECT minbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
															WHEN c.roleid = 3 then c.srecommend end
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END minbet
					   ,CASE WHEN @UpdateMaxBet = 1 THEN @MaxBet
							ELSE (SELECT maxbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
															WHEN c.roleid = 3 then c.srecommend end
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype	
									) END maxbet	
						,CASE WHEN @UpdateMPM = 1 THEN @MaxPerMatch
							ELSE (SELECT maxpermatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
															WHEN c.roleid = 3 then c.srecommend end
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END maxpermatch
						,NULL
						,CASE WHEN @UpdateMaxPayoutPM = 1 THEN @MaxPayoutPerMatch
							ELSE (SELECT MaxPayoutPerMatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
															WHEN c.roleid = 3 then c.srecommend end
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END MaxPayoutPerMatch
						,SYSDATETIME()			
				FROM #tblCust t
					INNER JOIN CustInfo c ON c.custid = t.custid
					CROSS JOIN #SportBettypeFilter s
				WHERE s.sporttype = @Sporttype AND s.SettingType = 10
					AND roleid BETWEEN 2 AND 4

				INSERT INTO Dep_CustBetSettingGameGroup_Member ([AgentID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch],RepUpdateTime)
				SELECT  t.custid			  
					   ,sporttype as [sporttype]
						,bettype as [bettype]
					   ,CASE WHEN @UpdateMinBet = 1 THEN @MinBet 
							ELSE (SELECT minbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = c.mrecommend 
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END minbet
					   ,CASE WHEN @UpdateMaxBet = 1 THEN @MaxBet
							ELSE (SELECT maxbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = c.mrecommend 
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END maxbet	
						,CASE WHEN @UpdateMPM = 1 THEN @MaxPerMatch
							ELSE (SELECT maxpermatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = c.mrecommend 
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END maxpermatch
						,NULL
						,CASE WHEN @UpdateMaxPayoutPM = 1 THEN @MaxPayoutPerMatch
							ELSE (SELECT MaxPayoutPerMatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = c.mrecommend 
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END MaxPayoutPerMatch
						,SYSDATETIME()			
				FROM #tblCust t
					INNER JOIN CustInfo c ON c.custid = t.custid
					CROSS JOIN #SportBettypeFilter s
				WHERE s.sporttype = @Sporttype AND s.SettingType = 10
					AND @ExistedMember = 1 AND roleid = 2

				INSERT INTO Dep_CustBetSettingGame_Member ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
				SELECT  t.custid			  
					   ,sporttype as [sporttype]
					   ,bettype as [bettype]
					   ,CASE WHEN @UpdateMinBet = 1 THEN @MinBet 
							ELSE (SELECT minbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = c.recommend 
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END minbet
					   ,CASE WHEN @UpdateMaxBet = 1 THEN @MaxBet
							ELSE (SELECT maxbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = CASE WHEN c.roleid = 1 then c.recommend 
															WHEN c.roleid = 2 then c.mrecommend 
															WHEN c.roleid = 3 then c.srecommend end
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype	
									) END maxbet	
						,CASE WHEN @UpdateMPM = 1 THEN @MaxPerMatch
							ELSE (SELECT maxpermatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = c.recommend 
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END maxpermatch
						,NULL
						,CASE WHEN @UpdateMaxPayoutPM = 1 THEN @MaxPayoutPerMatch
							ELSE (SELECT MaxPayoutPerMatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
									WHERE cs.custid = c.recommend 
										AND cs.sporttype= s.sporttype
										AND cs.bettype = s.bettype
									) END MaxPayoutPerMatch
						,SYSDATETIME()			
				FROM #tblCust t
					INNER JOIN CustInfo c ON c.custid = t.custid
					CROSS JOIN #SportBettypeFilter s
				WHERE s.sporttype = @Sporttype AND s.SettingType = 10
					AND @ExistedMember = 1 AND c.roleid = 1
			END

		IF @Sporttype = 161 --NumberGame
		BEGIN
			UPDATE cs  WITH(UPDLOCK,ROWLOCK)
				SET    cs.minbet = @MinBet, cs.maxbet = @maxbet, cs.MaxPerMatch = @MaxPerMatch, cs.MaxPerNumber =  @MaxPerBall
						,cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGame_Agent cs 
					INNER JOIN CustInfo c ON c.custid = cs.custid
				WHERE cs.Sporttype = @Sporttype
					AND c.custid IN (SELECT custid FROM #tblCust)
					AND roleid BETWEEN 2 AND 4

			IF @ExistedMember = 1
			BEGIN
				UPDATE cs  WITH(UPDLOCK,ROWLOCK)
				SET    cs.minbet = @MinBet, cs.maxbet = @maxbet, cs.MaxPerMatch = @MaxPerMatch, cs.MaxPerNumber =  @MaxPerBall
						,cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGameGroup_Member cs 
					INNER JOIN CustInfo c ON c.custid = cs.AgentID
				WHERE cs.Sporttype = @Sporttype
					AND c.custid IN (SELECT custid FROM #tblCust)
					AND c.roleid = 2

				UPDATE cs  WITH(UPDLOCK,ROWLOCK)
				SET    cs.minbet = @MinBet, cs.maxbet = @maxbet, cs.MaxPerMatch = @MaxPerMatch, cs.MaxPerNumber =  @MaxPerBall
						,cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGame_Member cs 
					INNER JOIN CustInfo c ON c.custid = cs.CustID
				WHERE cs.Sporttype = @Sporttype
					AND c.custid IN (SELECT custid FROM #tblCust)
					AND c.roleid = 1
			END

			DELETE t 
			FROM #tblCust t 
			INNER JOIN Dep_CustBetSettingGame_Agent cs on t.custid = cs.custid AND cs.sporttype = @Sporttype
			DELETE t 
			FROM #tblCust t 
			INNER JOIN Dep_CustBetSettingGameGroup_Member cs on t.custid = cs.AgentID AND cs.sporttype = @Sporttype
			DELETE t 
			FROM #tblCust t 
			INNER JOIN Dep_CustBetSettingGame_Member cs on t.custid = cs.custid AND cs.sporttype = @Sporttype
	 
			INSERT INTO Dep_CustBetSettingGame_Agent ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
			SELECT  t.custid			   
					,sporttype as [sporttype]
					,bettype as [bettype]
					,@minbet
					,@maxbet
					,@MaxPerMatch
					,@MaxPerBall
					,NULL
					,SYSDATETIME()
			FROM #tblCust t
				INNER JOIN CustInfo c ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s		
			WHERE s.sporttype = @Sporttype AND s.SettingType = 12
				AND roleid BETWEEN 2 AND 4
		
			INSERT INTO Dep_CustBetSettingGameGroup_Member ([AgentID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
			SELECT  t.custid
					,sporttype as [sporttype]
					,bettype as [bettype]
					,@minbet
					,@maxbet
					,@MaxPerMatch
					,@MaxPerBall
					,NULL
					,SYSDATETIME()
			FROM #tblCust t
				INNER JOIN CustInfo c ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s		
			WHERE s.sporttype = @Sporttype AND s.SettingType = 12
				AND @ExistedMember = 1 AND roleid = 2

			INSERT INTO Dep_CustBetSettingGame_Member ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
			SELECT  t.custid			  
					,sporttype as [sporttype]
					,bettype as [bettype]
					,@minbet
					,@maxbet
					,@MaxPerMatch
					,@MaxPerBall
					,NULL
					,SYSDATETIME()
			FROM #tblCust t
				INNER JOIN CustInfo c ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s		
			WHERE s.sporttype = @Sporttype AND s.SettingType = 12
				AND @ExistedMember = 1 AND roleid = 1	
		END 

		IF @Sporttype = 202 --Keno
		BEGIN
			DECLARE @BitmapOrder TINYINT
			SELECT @BitmapOrder = bitmapOrder FROM Dep_ProductStatusProfile WHERE Sporttype = @Sporttype and Bettype = @Bettype

			IF @Enable = 1 AND @EnableDownline = 0
			BEGIN
				UPDATE cg WITH(UPDLOCK,ROWLOCK)
				SET	bitmapIsDisabled  = dbo.f_GenerateProductStatus (cg.bitmapIsDisabled, @BitmapOrder,0),
					RepUpdateTime = SYSDATETIME()
				FROM Dep_CustProductStatus cg 
					INNER JOIN CustInfo c ON c.custid = cg.custid
				WHERE c.custid IN (SELECT custid FROM #tblCust)	
					AND roleid BETWEEN 2 AND 4
			END

			IF @Enable = 1 AND @EnableDownline = 1
			BEGIN
				UPDATE cg WITH(UPDLOCK,ROWLOCK)
				SET	bitmapIsDisabled  = dbo.f_GenerateProductStatus (cg.bitmapIsDisabled, @BitmapOrder,0),
					RepUpdateTime = SYSDATETIME()
				FROM Dep_CustProductStatus cg 
					INNER JOIN CustInfo c ON c.custid = cg.custid
				WHERE c.custid IN (SELECT custid FROM #tblCust)	
			END

			UPDATE cg WITH(UPDLOCK,ROWLOCK)
			SET	MinBet = @MinBet, 
				MaxBet = @MaxBet, 
				MaxPerMatch= @MaxPerMatch,
				RepUpdateTime = SYSDATETIME()
			FROM Dep_CustBetSetting_Agent cg 
				INNER JOIN CustInfo c ON c.custid = cg.custid
			WHERE cg.SportType = @Sporttype AND cg.BetType = @Bettype
				AND c.custid IN (SELECT custid FROM #tblCust)			
				AND roleid BETWEEN 2 AND 4

			IF @ExistedMember = 1
			BEGIN
				UPDATE cg WITH(UPDLOCK,ROWLOCK)
				SET	MinBet = @MinBet, 
					MaxBet = @MaxBet, 
					MaxPerMatch= @MaxPerMatch,
					RepUpdateTime = SYSDATETIME()
				FROM Dep_CustBetSetting_Member cg 
					INNER JOIN CustInfo c ON c.custid = cg.custid
				WHERE cg.SportType = @Sporttype AND cg.BetType = @Bettype
					AND c.custid IN (SELECT custid FROM #tblCust)	
					AND roleid = 1
			END

			DELETE t 
			FROM #tblCust t 
			INNER JOIN Dep_CustBetSetting_Agent cs on t.custid = cs.custid AND cs.SportType = @Sporttype AND BetType = @Bettype
			DELETE t 
			FROM #tblCust t 
			INNER JOIN Dep_CustBetSetting_Member cs on t.custid = cs.custid AND cs.SportType = @Sporttype AND BetType = @Bettype		

			INSERT INTO [dbo].Dep_CustBetSetting_Agent ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], RepUpdateTime)
			SELECT  t.custid
					,SportType
					,BetType
					,@minbet			
					,@maxbet			
					,@MaxPerMatch
					,SYSDATETIME()	
			FROM #tblCust t		
				INNER JOIN CustInfo c ON c.custid = t.custid	
				CROSS JOIN #SportBettypeFilter s		
			WHERE s.sporttype = @Sporttype AND BetType = @Bettype AND s.SettingType = 2
				AND roleid BETWEEN 2 AND 4

			INSERT INTO [dbo].Dep_CustBetSetting_Member ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], RepUpdateTime)
			SELECT  t.custid
					,SportType
					,BetType
					,@minbet			
					,@maxbet			
					,@MaxPerMatch	
					,SYSDATETIME()	
			FROM #tblCust t		
				INNER JOIN CustInfo c ON c.custid = t.custid	
				CROSS JOIN #SportBettypeFilter s		
			WHERE s.sporttype = @Sporttype AND BetType = @Bettype AND s.SettingType = 2
				AND @ExistedMember = 1 AND roleid = 1
		END

	END
	ELSE IF @Mode = 'Sportbook'
	BEGIN
		DECLARE @Product TINYINT, @iDoc INT
		CREATE TABLE #SportTypeBetType(SportType INT,Bettype INT,MinBet	MONEY,MaxBet MONEY,MaxPerMatch	MONEY,MaxPerNumber	MONEY,MaxPayoutPerMatch	MONEY,PRIMARY KEY(Sporttype ,Bettype))
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
		
		SELECT @ProductID = CASE	WHEN EXISTS (SELECT 1 FROM #SportTypeBetType ps 
													WHERE SportType IN (1,2,3,5,8,10,11,99,9901,9902,43,161,50,9907)) THEN 1 
									WHEN EXISTS (SELECT 1 FROM #SportTypeBetType ps WHERE SportType IN (161)) THEN 3
									WHEN EXISTS (SELECT 1 FROM #SportTypeBetType ps WHERE SportType IN (202)) THEN 8 END	

		INSERT INTO #SportBettypeFilter (ProductID,SportType,Bettype,IsLive,SettingType)
		SELECT @ProductID AS ProductID,SportType,Bettype,IsLive, SettingType 
		FROM dbo.f_Dep_CustSetting_SportBetTypeSettingSelect(@ProductID,NULL)

		--Create temp table containing all accounts belong to super, exclude fincance account
		CREATE TABLE #tblCustSB (custid INT)	
		INSERT INTO #tblCustSB(custid)
		SELECT VALUE AS RuleID 
		FROM STRING_SPLIT(@ids,',') WHERE VALUE <> ''
		IF @ProductID = 1 --Sportbook
		BEGIN	
			IF @Option  = 0
			BEGIN
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET cs.minbet = CASE WHEN roleid IN (3,4) AND cs.minbet <= s.MinBet AND @UpdCurency = 0 
									 THEN cs.MinBet ELSE s.MinBet END, 
					cs.maxbet = CASE WHEN roleid IN (3,4) AND cs.MaxBet >= s.MaxBet AND @UpdCurency = 0 
									 THEN cs.MaxBet ELSE s.MaxBet END,
					cs.MaxPerMatch = CASE WHEN roleid IN (3,4) AND cs.MaxPerMatch >= s.MaxPerMatch AND @UpdCurency = 0 
										  THEN cs.MaxPerMatch ELSE s.MaxPerMatch END , 
					cs.MaxPayoutPerMatch = CASE WHEN roleid IN (3,4) AND cs.MaxPayoutPerMatch >= s.MaxPayoutPerMatch AND @UpdCurency = 0 
												THEN cs.MaxPayoutPerMatch ELSE s.MaxPayoutPerMatch END,
					cs.RepUpdateTime = SYSDATETIME()							
				FROM dbo.Dep_CustBetSettingGame_Agent cs
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cs.custid
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)
					AND roleid BETWEEN 2 AND 4
			END

			IF @ExistedMember = 1
			BEGIN
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET cs.minbet = s.MinBet, 
					cs.maxbet = s.MaxBet,
					cs.MaxPerMatch = s.MaxPerMatch, 
					cs.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
					cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGameGroup_Member cs
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cs.AgentID
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)
					AND roleid = 2

				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET cs.minbet = s.MinBet, 
					cs.maxbet = s.MaxBet,
					cs.MaxPerMatch = s.MaxPerMatch, 
					cs.MaxPayoutPerMatch = s.MaxPayoutPerMatch,
					cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGame_Member cs
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cs.custid
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)
					AND roleid = 1
			END

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSettingGame_Agent cs WITH(NOLOCK) on t.custid = cs.custid
			INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSettingGameGroup_Member cs on t.custid = cs.AgentID
			INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSettingGame_Member cs WITH(NOLOCK) on t.custid = cs.custid
			INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
	 
			INSERT INTO Dep_CustBetSettingGame_Agent ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
			SELECT  t.custid			   
				   ,s.sporttype as [sporttype]
				   ,s.bettype as [bettype]
				   ,CASE WHEN l.SportType IS NOT NULl THEN l.MinBet 
						ELSE (SELECT minbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
														WHEN c.roleid = 3 then c.srecommend end
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END minbet
				   ,CASE WHEN l.SportType IS NOT NULl THEN l.MaxBet 
						ELSE (SELECT maxbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
														WHEN c.roleid = 3 then c.srecommend end
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype	
								) END maxbet	
					,CASE WHEN l.SportType IS NOT NULl THEN l.MaxPerMatch
						ELSE (SELECT maxpermatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
														WHEN c.roleid = 3 then c.srecommend end
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END maxpermatch
					,NULL
					,CASE WHEN l.SportType IS NOT NULl THEN l.MaxPayoutPerMatch
						ELSE (SELECT MaxPayoutPerMatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = CASE WHEN c.roleid = 2 then c.mrecommend 
														WHEN c.roleid = 3 then c.srecommend end
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END MaxPayoutPerMatch
					,SYSDATETIME()			
			FROM #tblCustSB t
				INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype
			WHERE roleid BETWEEN 2 AND 4  AND s.SettingType = 10

			INSERT INTO Dep_CustBetSettingGameGroup_Member ([AgentID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
			SELECT  t.custid			  
				    ,s.sporttype as [sporttype]
					,s.bettype as [bettype]
				   ,CASE WHEN l.SportType IS NOT NULl THEN l.MinBet 
						ELSE (SELECT minbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = c.mrecommend 
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END minbet
				   ,CASE WHEN l.SportType IS NOT NULl THEN l.MaxBet
						ELSE (SELECT maxbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = c.mrecommend 
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END maxbet	
					,CASE WHEN l.SportType IS NOT NULl THEN l.MaxPerMatch
						ELSE (SELECT maxpermatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = c.mrecommend 
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END maxpermatch
					,NULL
					,CASE WHEN l.SportType IS NOT NULl THEN l.MaxPayoutPerMatch
						ELSE (SELECT MaxPayoutPerMatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = c.mrecommend 
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END MaxPayoutPerMatch
					,SYSDATETIME()			
			FROM #tblCustSB t
				INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype
			WHERE @ExistedMember = 1 AND roleid = 2  AND s.SettingType = 10

			INSERT INTO Dep_CustBetSettingGame_Member ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
			SELECT  t.custid			  
				   ,s.sporttype as [sporttype]
				   ,s.bettype as [bettype]
				   ,CASE WHEN l.SportType IS NOT NULl THEN l.MinBet 
						ELSE (SELECT minbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = c.recommend 
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END minbet
				   ,CASE WHEN l.SportType IS NOT NULl THEN l.MaxBet
						ELSE (SELECT maxbet FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = CASE WHEN c.roleid = 1 then c.recommend 
														WHEN c.roleid = 2 then c.mrecommend 
														WHEN c.roleid = 3 then c.srecommend end
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype	
								) END maxbet	
					,CASE WHEN l.SportType IS NOT NULl THEN l.MaxPerMatch
						ELSE (SELECT maxpermatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = c.recommend 
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END maxpermatch
					,NULL
					,CASE WHEN l.SportType IS NOT NULl THEN l.MaxPayoutPerMatch
						ELSE (SELECT MaxPayoutPerMatch FROM Dep_CustBetSettingGame_Agent cs WITH(NOLOCK)
								WHERE cs.custid = c.recommend 
									AND cs.sporttype= s.sporttype
									AND cs.bettype = s.bettype
								) END MaxPayoutPerMatch
					,SYSDATETIME()			
			FROM #tblCustSB t
				INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype
			WHERE s.SettingType = 10 AND @ExistedMember = 1 AND c.roleid = 1
		END

		IF @ProductID = 3 --NumberGame
		BEGIN
			UPDATE cs  WITH(UPDLOCK,ROWLOCK)
				SET    cs.minbet = @MinBet, cs.maxbet = @maxbet, cs.MaxPerMatch = @MaxPerMatch, cs.MaxPerNumber =  @MaxPerBall
						,cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGame_Agent cs 
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cs.custid
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)
					AND roleid BETWEEN 2 AND 4

			IF @ExistedMember = 1
			BEGIN
				UPDATE cs  WITH(UPDLOCK,ROWLOCK)
				SET    cs.minbet = @MinBet, cs.maxbet = @maxbet, cs.MaxPerMatch = @MaxPerMatch, cs.MaxPerNumber =  @MaxPerBall
						,cs.RepUpdateTime = SYSDATETIME()				
				FROM dbo.Dep_CustBetSettingGameGroup_Member cs 
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cs.AgentID
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)
					AND c.roleid = 2

				UPDATE cs  WITH(UPDLOCK,ROWLOCK)
				SET    cs.minbet = @MinBet, cs.maxbet = @maxbet, cs.MaxPerMatch = @MaxPerMatch, cs.MaxPerNumber =  @MaxPerBall
						,cs.RepUpdateTime = SYSDATETIME()
				FROM dbo.Dep_CustBetSettingGame_Member cs 
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cs.CustID
					INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)
					AND c.roleid = 1
			END

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSettingGame_Agent cs WITH(NOLOCK) on t.custid = cs.custid AND cs.sporttype = @Sporttype

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSettingGameGroup_Member cs WITH(NOLOCK) on t.custid = cs.AgentID 
			INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSettingGame_Member cs WITH(NOLOCK) on t.custid = cs.custid 
			INNER JOIN #SportTypeBetType s ON cs.SportType = s.SportType AND cs.BetType = s.Bettype
	 
			INSERT INTO Dep_CustBetSettingGame_Agent ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch],RepUpdateTime)
			SELECT  t.custid			   
				   ,s.sporttype as [sporttype]
				   ,s.bettype as [bettype]
				   ,l.MinBet			
				   ,l.MaxBet			
				   ,l.MaxPerMatch
				   ,@MaxPerBall
				   ,NULL
				   ,SYSDATETIME()
			FROM #tblCustSB t
				INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s	
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype	
			WHERE s.SettingType = 12 AND roleid BETWEEN 2 AND 4
		
			INSERT INTO Dep_CustBetSettingGameGroup_Member ([AgentID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch],RepUpdateTime)
			SELECT  t.custid
				   ,s.sporttype as [sporttype]
				   ,s.bettype as [bettype]
				   ,l.MinBet			
				   ,l.MaxBet			
				   ,l.MaxPerMatch
				   ,@MaxPerBall
				   ,NULL
				   ,SYSDATETIME()
			FROM #tblCustSB t
				INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s	
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype	
			WHERE s.SettingType = 12 AND @ExistedMember = 1 AND roleid = 2

			INSERT INTO Dep_CustBetSettingGame_Member ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], [MaxPerNumber], [MaxPayoutPerMatch], RepUpdateTime)
			SELECT  t.custid			  
				   ,s.sporttype as [sporttype]
				   ,s.bettype as [bettype]
				   ,l.MinBet			
				   ,l.MaxBet			
				   ,l.MaxPerMatch
				   ,@MaxPerBall
				   ,NULL
				   ,SYSDATETIME()
			FROM #tblCustSB t
				INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = t.custid
				CROSS JOIN #SportBettypeFilter s
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype		
			WHERE s.SettingType = 12 AND @ExistedMember = 1 AND roleid = 1	
		END 

		IF @ProductID = 8 --Keno
		BEGIN
			DECLARE @BitmapOrderKN TINYINT
			SET @BitmapOrderKN = (SELECT  bitmapOrder FROM Dep_ProductStatusProfile D  WITH(NOLOCK)
										INNER JOIN #SportTypeBetType l on D.Sporttype = l.SportType AND D.Bettype = l.Bettype)

			IF @Enable = 1 AND @EnableDownline = 0
			BEGIN
				UPDATE cg WITH(UPDLOCK,ROWLOCK)
				SET	bitmapIsDisabled  = dbo.f_GenerateProductStatus (cg.bitmapIsDisabled, @BitmapOrderKN,0),
					RepUpdateTime = SYSDATETIME()
				FROM Dep_CustProductStatus cg 
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cg.custid
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)	
					AND roleid BETWEEN 2 AND 4
			END

			IF @Enable = 1 AND @EnableDownline = 1
			BEGIN
				UPDATE cg WITH(UPDLOCK,ROWLOCK)
				SET	bitmapIsDisabled  = dbo.f_GenerateProductStatus (cg.bitmapIsDisabled, @BitmapOrderKN,0),
					RepUpdateTime = SYSDATETIME()
				FROM Dep_CustProductStatus cg 
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cg.custid
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)	
			END

			UPDATE cg WITH(UPDLOCK,ROWLOCK)
			SET	MinBet = @MinBet, 
				MaxBet = @MaxBet, 
				MaxPerMatch= @MaxPerMatch,
				RepUpdateTime = SYSDATETIME()
			FROM Dep_CustBetSetting_Agent cg 
				INNER JOIN CustInfo c ON c.custid = cg.custid
				INNER JOIN #SportTypeBetType l on cg.Sporttype = l.SportType AND cg.Bettype = l.Bettype
			WHERE c.custid IN (SELECT custid FROM #tblCustSB)			
				AND roleid BETWEEN 2 AND 4

			IF @ExistedMember = 1
			BEGIN
				UPDATE cg WITH(UPDLOCK,ROWLOCK)
				SET	MinBet = @MinBet, 
					MaxBet = @MaxBet, 
					MaxPerMatch= @MaxPerMatch,
					RepUpdateTime = SYSDATETIME()
				FROM Dep_CustBetSetting_Member cg 
					INNER JOIN CustInfo c WITH(NOLOCK) ON c.custid = cg.custid
					INNER JOIN #SportTypeBetType l on cg.Sporttype = l.SportType AND cg.Bettype = l.Bettype
				WHERE c.custid IN (SELECT custid FROM #tblCustSB)	
					AND roleid = 1
			END

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSetting_Agent cs on t.custid = cs.custid 
			INNER JOIN #SportTypeBetType l on cs.Sporttype = l.SportType AND cs.Bettype = l.Bettype

			DELETE t 
			FROM #tblCustSB t 
			INNER JOIN Dep_CustBetSetting_Member cs on t.custid = cs.custid 
			INNER JOIN #SportTypeBetType l on cs.Sporttype = l.SportType AND cs.Bettype = l.Bettype		

			INSERT INTO [dbo].Dep_CustBetSetting_Agent ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch], RepUpdateTime)
			SELECT  t.custid
				   ,s.SportType
				   ,s.BetType
				   ,l.MinBet			
				   ,l.MaxBet			
				   ,l.MaxPerMatch
				   ,SYSDATETIME()
			FROM #tblCustSB t		
				INNER JOIN CustInfo c ON c.custid = t.custid	
				CROSS JOIN #SportBettypeFilter s
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype			
			WHERE s.SettingType = 2 AND roleid BETWEEN 2 AND 4

			INSERT INTO [dbo].Dep_CustBetSetting_Member ([CustID], [SportType], [BetType], [MinBet], [MaxBet], [MaxPerMatch],RepUpdateTime)
			SELECT  t.custid
				   ,s.SportType
				   ,s.BetType
				   ,l.MinBet			
				   ,l.MaxBet			
				   ,l.MaxPerMatch	
				   ,SYSDATETIME()
			FROM #tblCustSB t		
				INNER JOIN CustInfo c ON c.custid = t.custid	
				CROSS JOIN #SportBettypeFilter s
				INNER JOIN #SportTypeBetType l on s.Sporttype = l.SportType AND s.Bettype = l.Bettype			
			WHERE s.SettingType = 2 AND @ExistedMember = 1 AND roleid = 1

			DROP TABLE #tblCustSB
		END
	END
END	