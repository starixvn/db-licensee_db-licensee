ALTER PROCEDURE [dbo].[Acc_CustSetting3rd_11]
	@ids VARCHAR(MAX)
	,@srecommend INT
	,@Sporttype INT
	,@Bettype INT = 0
	,@MinBet MONEY
	,@MaxBet MONEY
	,@MaxPerMatch MONEY
	,@MaxPerBall MONEY = 0
	,@ExistedMember BIT
	,@Enable BIT = 0 
	,@EnableDownline BIT = 0
AS
/*
	Created: Elodie
	Date: 20150108
	Task : Licensee Setting Configuration - Update Bet Setting [#6304]
	DB: DBCUST/CustDB
	Original:

	Revisions:

	Param's Explanation:
		
*/ 
BEGIN

	SET NOCOUNT ON
	
	IF (SELECT COUNT(1) FROM sys.objects WHERE name IN ('Dep_Custsetting3rd','custinfo','Dep_CustSetting') AND type = 'U') <> 3
		RETURN
	
	DECLARE @string VARCHAR(MAX), @splitter CHAR(1), @xml XML
	SELECT @splitter = ',', @string = @ids

	SET @xml = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

	--Create temp table containing all accounts belong to super, exclude fincance account
	CREATE TABLE #tblCust (custid INT)
	INSERT INTO #tblCust(custid)
	SELECT r.value('.','VARCHAR(12)')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	
	IF @Sporttype IN (1,2,3,5,8,10,11,99,154) --Sportbook
	BEGIN
		UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
		SET  maxpermatch =	CASE WHEN @Sporttype = 1 THEN @MaxPerMatch ELSE maxpermatch END
			,maxpermatch2 =	CASE WHEN @Sporttype = 2 THEN @MaxPerMatch ELSE maxpermatch2 END 
			,maxpermatch3 = CASE WHEN @Sporttype = 3 THEN @MaxPerMatch ELSE maxpermatch3 END
			,maxpermatch5 = CASE WHEN @Sporttype = 5 THEN @MaxPerMatch ELSE maxpermatch5 END
			,maxpermatch8 = CASE WHEN @Sporttype = 8 THEN @MaxPerMatch ELSE maxpermatch8 END
			,maxpermatch10 = CASE WHEN @Sporttype = 10 THEN @MaxPerMatch ELSE maxpermatch10 END
			,maxpermatch11 = CASE WHEN @Sporttype = 11 THEN @MaxPerMatch ELSE maxpermatch11 END
			,maxpermatch99 = CASE WHEN @Sporttype = 99 AND @Bettype = 1 THEN @MaxPerMatch ELSE maxpermatch99 END
			,MaxPerMatch99MP = CASE WHEN @Sporttype = 99 AND @Bettype = 9 THEN @MaxPerMatch ELSE MaxPerMatch99MP END
			,maxpermatch154	= CASE WHEN @Sporttype = 154 THEN @MaxPerMatch ELSE maxpermatch154 END						
		WHERE custid IN (SELECT custid FROM #tblCust) 
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END

		UPDATE cs WITH(UPDLOCK,ROWLOCK)
		SET    cs.minbet = @MinBet, cs.maxbet = @maxbet
		FROM dbo.Dep_CustSetting cs
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE cs.Sporttype = @Sporttype
			AND 1 = CASE	WHEN @Sporttype <> 99 THEN 1 
							WHEN @Sporttype = 99 AND @Bettype = 9 AND cs.bettype = 9 THEN 1
							WHEN @Sporttype = 99 AND @Bettype = 1 AND cs.bettype <> 9 THEN 1 ELSE 0 END
			AND c.custid IN (SELECT custid FROM #tblCust)
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END

		 DELETE t 
		 FROM #tblCust t 
		 INNER JOIN Dep_CustSetting cs on t.custid = cs.custid AND cs.sporttype = @Sporttype AND bettype = @Bettype
	 
		INSERT INTO [dbo].[Dep_CustSetting]
				   ([custid]
				   ,[bettype]
				   ,[sporttype]
				   ,[islive]
				   ,[apositiontaking]
				   ,[mpositiontaking]
				   ,[spositiontaking]
				   ,[playerdiscount]
				   ,[discount]
				   ,[adiscount]
				   ,[sdiscount]
				   ,[minbet]
				   ,[maxbet])
		SELECT  t.custid
			   ,bettype as [bettype]
			   ,sporttype as [sporttype]
			   ,islive as [islive]
			   ,0 as [apositiontaking]
			   ,0 as [mpositiontaking]
			   ,0 as [spositiontaking]
			   ,0 as [playerdiscount]
			   ,0 as [discount]
			   ,0 as [adiscount]
			   ,0 as [sdiscount]
			   ,@minbet
			   ,@maxbet
		FROM #tblCust t
			CROSS JOIN (		  SELECT 1		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 1		AS bettype, 1	AS islive
						UNION ALL SELECT 1		AS sporttype, 2		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 3		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 3		AS bettype, 1	AS islive
						UNION ALL SELECT 1		AS sporttype, 4		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 5		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 6		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 7		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 7		AS bettype, 1	AS islive
						UNION ALL SELECT 1		AS sporttype, 8		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 8		AS bettype, 1	AS islive
						UNION ALL SELECT 1		AS sporttype, 9		AS bettype, 0	AS islive
						UNION ALL SELECT 1		AS sporttype, 10	AS bettype, 0	AS islive
						UNION ALL SELECT 2		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 2		AS sporttype, 2		AS bettype, 0	AS islive
						UNION ALL SELECT 2		AS sporttype, 3		AS bettype, 0	AS islive
						UNION ALL SELECT 2		AS sporttype, 7		AS bettype, 0	AS islive
						UNION ALL SELECT 2		AS sporttype, 8		AS bettype, 0	AS islive
						UNION ALL SELECT 2		AS sporttype, 20	AS bettype, 0	AS islive
						UNION ALL SELECT 3		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 3		AS sporttype, 2		AS bettype, 0	AS islive
						UNION ALL SELECT 3		AS sporttype, 3		AS bettype, 0	AS islive
						UNION ALL SELECT 3		AS sporttype, 20	AS bettype, 0	AS islive
						UNION ALL SELECT 5		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 5		AS sporttype, 2		AS bettype, 0	AS islive
						UNION ALL SELECT 5		AS sporttype, 3		AS bettype, 0	AS islive
						UNION ALL SELECT 5		AS sporttype, 20	AS bettype, 0	AS islive
						UNION ALL SELECT 8		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 8		AS sporttype, 3		AS bettype, 0	AS islive
						UNION ALL SELECT 8		AS sporttype, 20	AS bettype, 0	AS islive
						UNION ALL SELECT 10		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 10		AS sporttype, 2		AS bettype, 0	AS islive
						UNION ALL SELECT 10		AS sporttype, 3		AS bettype, 0	AS islive
						UNION ALL SELECT 10		AS sporttype, 20	AS bettype, 0	AS islive
						UNION ALL SELECT 11		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 11		AS sporttype, 20	AS bettype, 0	AS islive
						UNION ALL SELECT 99		AS sporttype, 1		AS bettype, 0	AS islive
						UNION ALL SELECT 99		AS sporttype, 2		AS bettype, 0	AS islive
						UNION ALL SELECT 99		AS sporttype, 3		AS bettype, 0	AS islive
						UNION ALL SELECT 99		AS sporttype, 9		AS bettype, 0	AS islive
						UNION ALL SELECT 99		AS sporttype, 20	AS bettype, 0	AS islive
						UNION ALL SELECT 154	AS sporttype, 20	AS bettype, 0	AS islive
						) s
		WHERE s.sporttype = @Sporttype		
	END

	IF @Sporttype = 161 --NumberGame
	BEGIN		
		UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
		SET maxpermatch161 = @MaxPerMatch,
			MaxPerBall161 = @MaxPerBall
		WHERE custid IN (SELECT custid FROM #tblCust) 
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END

		UPDATE cs  WITH(UPDLOCK,ROWLOCK)
		SET    cs.minbet = @MinBet, cs.maxbet = @maxbet
		FROM dbo.Dep_CustSetting3rd cs 
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE cs.Sporttype = @Sporttype
			AND c.custid IN (SELECT custid FROM #tblCust)
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END

		DELETE t 
		FROM #tblCust t 
		INNER JOIN Dep_CustSetting3rd cs on t.custid = cs.custid AND cs.sporttype = @Sporttype
	 
		INSERT INTO [dbo].[Dep_CustSetting3rd]
				   ([custid]
				   ,[bettype]
				   ,[sporttype]
				   ,[islive]
				   ,[apositiontaking]
				   ,[mpositiontaking]
				   ,[spositiontaking]
				   ,[playerdiscount]
				   ,[discount]
				   ,[adiscount]
				   ,[sdiscount]
				   ,[minbet]
				   ,[maxbet])
		SELECT  t.custid
			   ,bettype	as [bettype]
			   ,161		as [sporttype]
			   ,islive	as [islive]
			   ,0 as [apositiontaking]
			   ,0 as [mpositiontaking]
			   ,0 as [spositiontaking]
			   ,0 as [playerdiscount]
			   ,0 as [discount]
			   ,0 as [adiscount]
			   ,0 as [sdiscount]
			   ,@minbet
			   ,@maxbet
		FROM #tblCust t
			CROSS JOIN (		  SELECT 81	AS bettype, 0 AS islive
						UNION ALL SELECT 83	AS bettype, 0 AS islive
						UNION ALL SELECT 85	AS bettype, 1 AS islive
						UNION ALL SELECT 86	AS bettype, 0 AS islive
						UNION ALL SELECT 86	AS bettype, 1 AS islive
						UNION ALL SELECT 87	AS bettype, 1 AS islive
						UNION ALL SELECT 88	AS bettype, 0 AS islive
						UNION ALL SELECT 89	AS bettype, 1 AS islive
						UNION ALL SELECT 90	AS bettype, 1 AS islive
						) s			
	END 

	IF @Sporttype BETWEEN 151 AND 153 --Racing
	BEGIN		
		UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
		SET  MaxPerMatch151 = CASE WHEN @Sporttype = 151 AND @Bettype = 31 THEN @MaxPerMatch ELSE MaxPerMatch151 END
			,MaxPerMatch151_OT = CASE WHEN @Sporttype = 151 AND @Bettype = 41 THEN @MaxPerMatch ELSE MaxPerMatch151_OT END
			,MaxPerMatch151_AU = CASE WHEN @Sporttype = 151 AND @Bettype = 51 THEN @MaxPerMatch ELSE MaxPerMatch151_AU END
			,MaxPerMatch152_UK = CASE WHEN @Sporttype = 152 AND @Bettype = 41 THEN @MaxPerMatch ELSE MaxPerMatch152_UK END
			,MaxPerMatch152_AU = CASE WHEN @Sporttype = 152 AND @Bettype = 51 THEN @MaxPerMatch ELSE MaxPerMatch152_AU END
			,MaxPerMatch153_AU = CASE WHEN @Sporttype = 153 AND @Bettype = 51 THEN @MaxPerMatch ELSE MaxPerMatch153_AU END
			,DisableHorseracing = CASE WHEN @Sporttype = 151 AND @Bettype = 31 AND @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE DisableHorseracing END
			,DisableOpenTote = CASE WHEN @Sporttype = 151 AND @Bettype = 41 AND @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE DisableOpenTote END
			,Disable151_AU = CASE WHEN @Sporttype = 151 AND @Bettype = 51 AND @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE Disable151_AU END
			,Disable152_UK = CASE WHEN @Sporttype = 152 AND @Bettype = 41 AND @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE Disable152_UK END
			,Disable152_AU = CASE WHEN @Sporttype = 152 AND @Bettype = 51 AND @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE Disable152_AU END
			,Disable153_AU = CASE WHEN @Sporttype = 153 AND @Bettype = 51 AND @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE Disable153_AU END			
		WHERE custid IN (SELECT custid FROM #tblCust) 
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END

		UPDATE cs  WITH(UPDLOCK,ROWLOCK)
		SET    cs.minbet = @MinBet, cs.maxbet = @maxbet
		FROM dbo.Dep_CustSetting3rd cs 
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE cs.Sporttype = @Sporttype
			AND 1 = CASE	WHEN @Bettype = 31 AND cs.bettype IN (31,32) THEN 1 
							WHEN @Bettype = 41 AND cs.bettype IN (41,42) THEN 1 
							WHEN @Bettype = 51 AND cs.bettype IN (51,52) THEN 1 ELSE 0 END
			AND c.custid IN (SELECT custid FROM #tblCust)
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END

		DELETE t 
		FROM #tblCust t 
		INNER JOIN Dep_CustSetting3rd cs on t.custid = cs.custid AND cs.sporttype = @Sporttype AND cs.bettype = @Bettype
	 
		INSERT INTO [dbo].[Dep_CustSetting3rd]
				   ([custid]
				   ,[bettype]
				   ,[sporttype]
				   ,[islive]
				   ,[apositiontaking]
				   ,[mpositiontaking]
				   ,[spositiontaking]
				   ,[playerdiscount]
				   ,[discount]
				   ,[adiscount]
				   ,[sdiscount]
				   ,[minbet]
				   ,[maxbet])
		SELECT  t.custid
			   ,bettype		as [bettype]
			   ,sporttype	as [sporttype]
			   ,0			as [islive]
			   ,0 as [apositiontaking]
			   ,0 as [mpositiontaking]
			   ,0 as [spositiontaking]
			   ,0 as [playerdiscount]
			   ,0 as [discount]
			   ,0 as [adiscount]
			   ,0 as [sdiscount]
			   ,@minbet
			   ,@maxbet
		FROM #tblCust t
			CROSS JOIN (		  SELECT 151 AS sporttype, 31 AS bettype 
						UNION ALL SELECT 151 AS sporttype, 32 AS bettype 
						UNION ALL SELECT 151 AS sporttype, 41 AS bettype 
						UNION ALL SELECT 151 AS sporttype, 42 AS bettype 
						UNION ALL SELECT 151 AS sporttype, 51 AS bettype 
						UNION ALL SELECT 151 AS sporttype, 52 AS bettype 
						UNION ALL SELECT 152 AS sporttype, 41 AS bettype 
						UNION ALL SELECT 152 AS sporttype, 42 AS bettype 
						UNION ALL SELECT 152 AS sporttype, 51 AS bettype 
						UNION ALL SELECT 152 AS sporttype, 52 AS bettype 
						UNION ALL SELECT 153 AS sporttype, 51 AS bettype 
						UNION ALL SELECT 153 AS sporttype, 52 AS bettype 
						) s	
		WHERE s.sporttype = @Sporttype 
			AND 1 = CASE	WHEN @Bettype = 31 AND s.bettype IN (31,32) THEN 1
							WHEN @Bettype = 41 AND s.bettype IN (41,42) THEN 1
							WHEN @Bettype = 51 AND s.bettype IN (51,52) THEN 1 ELSE 0 END
	END 

	IF @Sporttype BETWEEN 180 AND 186 --Virtual sport
	BEGIN		
		DECLARE @ptVALUE SMALLMONEY
		SELECT @ptVALUE = spositiontaking FROM Dep_CustSetting3rd WITH (NOLOCK) WHERE custid = @srecommend

		UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
		SET  maxpermatch180 = CASE WHEN @Sporttype = 180 THEN @MaxPerMatch ELSE maxpermatch180 END
			,maxpermatch181 = CASE WHEN @Sporttype = 181 THEN @MaxPerMatch ELSE maxpermatch181 END				
			,maxpermatch182 = CASE WHEN @Sporttype = 182 THEN @MaxPerMatch ELSE maxpermatch182 END				
			,maxpermatch183 = CASE WHEN @Sporttype = 183 THEN @MaxPerMatch ELSE maxpermatch183 END				
			,maxpermatch184 = CASE WHEN @Sporttype = 184 THEN @MaxPerMatch ELSE maxpermatch184 END				
			,maxpermatch185 = CASE WHEN @Sporttype = 185 THEN @MaxPerMatch ELSE maxpermatch185 END				
			,maxpermatch186 = CASE WHEN @Sporttype = 186 THEN @MaxPerMatch ELSE maxpermatch186 END						
			,DisableVirtualSports = CASE WHEN @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE DisableVirtualSports END
			,HideVirtualSports = CASE WHEN @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE HideVirtualSports END
		WHERE custid IN (SELECT custid FROM #tblCust) 
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END
		
		UPDATE cs  WITH(UPDLOCK,ROWLOCK)
		SET    cs.minbet = @MinBet, cs.maxbet = @maxbet
		FROM dbo.Dep_CustSetting3rd cs 
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE cs.Sporttype = @Sporttype			
			AND c.custid IN (SELECT custid FROM #tblCust)
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END

		-- Remove Virtual sport that having setting in Dep_CustSetting3rd
		DELETE t 
		FROM #tblCust t 
		INNER JOIN Dep_CustSetting3rd cs on t.custid = cs.custid AND cs.sporttype = @Sporttype
	 
		INSERT INTO [dbo].[Dep_CustSetting3rd]
				   ([custid]
				   ,[bettype]
				   ,[sporttype]
				   ,[islive]
				   ,[apositiontaking]
				   ,[mpositiontaking]
				   ,[spositiontaking]
				   ,[playerdiscount]
				   ,[discount]
				   ,[adiscount]
				   ,[sdiscount]
				   ,[minbet]
				   ,[maxbet])
		SELECT  t.custid
			   ,bettype as [bettype]
			   ,sporttype as [sporttype]
			   ,0 as [islive]
			   ,0 as [apositiontaking]
			   ,0 as [mpositiontaking]
			   ,0 as [spositiontaking]
			   ,0 as [playerdiscount]
			   ,0 as [discount]
			   ,0 as [adiscount]
			   ,0 as [sdiscount]
			   ,@minbet
			   ,@maxbet
		FROM #tblCust t
			CROSS JOIN (		  SELECT 180 as sporttype, 1201 as bettype 
						UNION ALL SELECT 181 as sporttype, 1231 as bettype 
						UNION ALL SELECT 182 as sporttype, 1231 as bettype 
						UNION ALL SELECT 183 as sporttype, 1231 as bettype 
						UNION ALL SELECT 184 as sporttype, 1231 as bettype 
						UNION ALL SELECT 185 as sporttype, 1231 as bettype 
						UNION ALL SELECT 186 as sporttype, 1220 as bettype 
						) s
		WHERE s.sporttype = @Sporttype		
	END 

	IF @Sporttype = 202 --Keno
	BEGIN
		UPDATE cg WITH(UPDLOCK,ROWLOCK)
		SET	MinBet=@MinBet, 
			MaxBet=@Maxbet, 
			MaxPerGameType= @MaxPerMatch,
			IsDisabled = CASE WHEN @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE cg.IsDisabled END	
		FROM CustGameType cg 
			INNER JOIN bodb02.dbo.GameType gt ON cg.GameTypeID = gt.GameTypeID
			INNER JOIN CustInfo c ON c.custid = cg.custid
		WHERE gt.IBCBetTypeID = @Bettype
			AND c.custid IN (SELECT custid FROM #tblCust)			
			AND 1 = CASE WHEN @ExistedMember = 0 AND roleid = 1 THEN 0 ELSE 1 END
		
		DELETE t 
		FROM #tblCust t 
		INNER JOIN CustGameType cs on t.custid = cs.custid
		INNER JOIN bodb02.dbo.GameType gt ON cs.GameTypeID = gt.GameTypeID AND gt.IBCBetTypeID = @Bettype
	 
		INSERT INTO [dbo].[CustGameType]
           ([CustID]
           ,[GameTypeID]
           ,[StakeLevelList]
           ,[MaxPerGameType]
           ,[MinBet]
           ,[MaxBet]
           ,[IsDisabled])
		SELECT  t.custid
			   ,1				as [GameTypeID]
			   ,''				as [StakeLevelList]
			   ,@MaxPerMatch	as [MaxPerGameType]
			   ,@minbet			as [MinBet]
			   ,@maxbet			as [MaxBet]
			   ,CASE WHEN @Enable = 1 AND @EnableDownline = 1 THEN 0 ELSE 1 END	as [IsDisabled]			 
		FROM #tblCust t			
	END
	DROP TABLE #tblCust
END





