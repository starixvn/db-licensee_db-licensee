/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_CustomerBetSettingCheck] 
	@CustID INT	
	,@Sporttype INT
	,@Bettype INT = 0
	,@MinBet MONEY
	,@MaxBet MONEY
	,@MaxPerMatch MONEY
	
	,@ExistedMember BIT
	,@AgentID INT = 0
	,@IsAgentOnly BIT = 0
	,@UpdateMinBet BIT = 0
	,@UpdateMaxBet BIT = 0
	,@UpdateMPM BIT = 0	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20211229@Johnson
	Task : Licensee Setting Configuration - Check bet settings for sub agent 
	DB: DBCUST/CustDB
	Original:

	Revisions:
		   - 20211224@Johnson: Initial sp [redmine: #165885]
    Param's Explanation:
		- @CustID : super ID
		
*/ 
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #DummyMaster(custid INT PRIMARY KEY)
	INSERT INTO #DummyMaster(custid)
	SELECT custid FROM custinfo WITH(NOLOCK)
	WHERE srecommend = @CustID AND roleid=3
		AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88' + 'CAS%')


	IF @ExistedMember = 0
	BEGIN
		IF EXISTS (SELECT 1 
			FROM Dep_CustSetting cs WITH(NOLOCK)
				INNER JOIN custinfo ci WITH(NOLOCK) ON cs.custid = ci.custid
				CROSS APPLY (SELECT CASE WHEN @sporttype = 1 AND @Bettype <> 9 THEN maxpermatch
										WHEN @sporttype = 1 AND @Bettype = 9 THEN MaxPerMatch1MP
										WHEN @sporttype = 1 AND @Bettype = 99 THEN MaxPerMatch99
										WHEN @sporttype = 2 THEN maxpermatch2
										WHEN @sporttype = 3 THEN maxpermatch3
										WHEN @sporttype = 5 THEN maxpermatch5
										WHEN @sporttype = 8 THEN maxpermatch8
										WHEN @sporttype = 10 THEN maxpermatch10
										WHEN @sporttype = 11 THEN maxpermatch11
										WHEN @sporttype = 99 AND @Bettype = 9 THEN MaxPerMatch99MP
									END as MaxPerMatch	
							FROM custinfo c WITH(NOLOCK) 
							WHERE c.custid = ci.custid) b
			WHERE ci.srecommend = @custid
				AND ci.mrecommend NOT IN (SELECT custid FROM #DummyMaster)
				AND 1 = CASE WHEN @IsAgentOnly = 1 AND ((@AgentID = 0 AND roleid =2) OR (@AgentID <> 0 AND ci.custid = @AgentID)) THEN 1 
							WHEN @IsAgentOnly = 0 AND roleid IN (2,3,4) THEN 1
							ELSE 0 END
				AND sporttype = @sporttype
				AND bettype = @bettype
				AND 1 = CASE WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 0 AND @UpdateMPM = 0 AND @MinBet <= MinBet THEN 1
							WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 1 AND @UpdateMPM = 0 AND @MaxBet >= MaxBet THEN 1
							WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 0 AND @UpdateMPM = 1 AND @MaxPerMatch >= b.MaxPerMatch THEN 1
							ELSE 0 END
			)
		BEGIN
			SELECT @ErrCode = 100,
				@ErrMsg = CASE WHEN @UpdateMinBet = 1 THEN 'New Min Bet must be less than or equal current Min Bet'
							WHEN @UpdateMaxBet = 1 THEN 'New Max Bet must be greater than or equal current Max Bet'
							WHEN @UpdateMPM = 1 THEN 'New Match Per Match must be greater than or equal current Match Per Match'
							END
			RETURN						
		END	

		IF EXISTS (SELECT 1 
			FROM Dep_CustSetting cs WITH(NOLOCK)
				INNER JOIN custinfo ci WITH(NOLOCK) ON cs.custid = ci.custid
				CROSS APPLY (SELECT CASE WHEN @sporttype = 1 AND @Bettype <> 9 THEN maxpermatch
										WHEN @sporttype = 1 AND @Bettype = 9 THEN MaxPerMatch1MP
										WHEN @sporttype = 1 AND @Bettype = 99 THEN MaxPerMatch99
										WHEN @sporttype = 2 THEN maxpermatch2
										WHEN @sporttype = 3 THEN maxpermatch3
										WHEN @sporttype = 5 THEN maxpermatch5
										WHEN @sporttype = 8 THEN maxpermatch8
										WHEN @sporttype = 10 THEN maxpermatch10
										WHEN @sporttype = 11 THEN maxpermatch11
										WHEN @sporttype = 99 AND @Bettype = 9 THEN MaxPerMatch99MP
									END as MaxPerMatch	
							FROM custinfo c WITH(NOLOCK) 
							WHERE c.custid = ci.custid) b
			WHERE ci.srecommend = @custid
				AND ci.mrecommend NOT IN (SELECT custid FROM #DummyMaster)
				AND 1 = CASE WHEN @IsAgentOnly = 1 AND ((@AgentID = 0 AND roleid =2) OR (@AgentID <> 0 AND ci.custid = @AgentID)) THEN 1 
							WHEN @IsAgentOnly = 0 AND roleid IN (2,3,4) THEN 1
							ELSE 0 END							
				AND sporttype = @sporttype
				AND bettype = @bettype
				AND 1 = CASE WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 0 AND @UpdateMPM = 0 AND @MinBet > MaxBet THEN 1
							WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 1 AND @UpdateMPM = 0 AND (@MaxBet < MinBet OR @MaxBet > b.MaxPerMatch) THEN 1
							WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 0 AND @UpdateMPM = 1 AND @MaxPerMatch < MaxBet THEN 1
							
							WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 1 AND @UpdateMPM = 0 AND (@MinBet > @MaxBet OR @MaxBet > b.MaxPerMatch) THEN 1
							WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 0 AND @UpdateMPM = 1 AND (@MinBet > MaxBet OR MaxBet > @MaxPerMatch) THEN 1
							WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 1 AND @UpdateMPM = 1 AND (Minbet > @MaxBet OR @MaxPerMatch < @MaxBet) THEN 1
							
							WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 1 AND @UpdateMPM = 1 AND (@MinBet > @MaxBet OR @MaxBet > @MaxPerMatch) THEN 1
							ELSE 0 END
			)
		BEGIN
			SELECT @ErrCode = 101,
				@ErrMsg = 'There are some customers having Bet Setting don''t follow the rule below. Please check again!'
			RETURN						
		END		
	END	
	ELSE 
	BEGIN		
		IF @IsAgentOnly = 1
		BEGIN
			IF EXISTS (SELECT 1 
				FROM Dep_CustSetting cs WITH(NOLOCK)
					INNER JOIN customer ci WITH(NOLOCK) ON cs.custid = ci.custid
					CROSS APPLY (SELECT TOP 1 CASE WHEN @sporttype = 1 AND @Bettype NOT IN (9,99) THEN maxpermatch
											WHEN @sporttype = 1 AND @Bettype = 9 THEN MaxPerMatch1MP
											WHEN @sporttype = 1 AND @Bettype = 99 THEN MaxPerMatch99
											WHEN @sporttype = 2 THEN maxpermatch2
											WHEN @sporttype = 3 THEN maxpermatch3
											WHEN @sporttype = 5 THEN maxpermatch5
											WHEN @sporttype = 8 THEN maxpermatch8
											WHEN @sporttype = 10 THEN maxpermatch10
											WHEN @sporttype = 11 THEN maxpermatch11
											WHEN @sporttype = 99 AND @Bettype = 9 THEN MaxPerMatch99MP
										END as MaxPerMatch	
								FROM custinfo c WITH(NOLOCK) 
								WHERE c.custid = ci.custid) b
				WHERE ci.srecommend = @custID
					AND ci.mrecommend NOT IN (SELECT custid FROM #DummyMaster)
					AND 1 = CASE WHEN ((@AgentID = 0 AND roleid IN (1,2)) OR (@AgentID <> 0 AND ci.recommend = @AgentID)) THEN 1 
								ELSE 0 END					
					AND ci.username NOT LIKE '%CashOut%'
					AND ci.username  NOT LIKE '%OddsAdj%'
					AND ci.username  NOT LIKE '%ClearBal%'
					AND ci.username  NOT LIKE '%Bettrade%'					
					AND sporttype = @sporttype
					AND bettype = @bettype
					AND 1 = CASE WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 0 AND @UpdateMPM = 0 AND @MinBet > MaxBet THEN 1
								WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 1 AND @UpdateMPM = 0 AND (@MaxBet < MinBet OR @MaxBet > b.MaxPerMatch) THEN 1
								WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 0 AND @UpdateMPM = 1 AND @MaxPerMatch < MaxBet THEN 1
								
								WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 1 AND @UpdateMPM = 0 AND (@MinBet > @MaxBet OR @MaxBet > b.MaxPerMatch) THEN 1
								WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 0 AND @UpdateMPM = 1 AND (@MinBet > MaxBet OR MaxBet > @MaxPerMatch) THEN 1
								WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 1 AND @UpdateMPM = 1 AND (Minbet > @MaxBet OR @MaxPerMatch < @MaxBet) THEN 1
								
								WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 1 AND @UpdateMPM = 1 AND (@MinBet > @MaxBet OR @MaxBet > @MaxPerMatch) THEN 1
								ELSE 0 END
				)
			BEGIN
				SELECT @ErrCode = 102,
					@ErrMsg = 'There are some customers having Bet Setting don''t follow the rule below. Please check again!'
				RETURN						
			END	
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT 1 
				FROM Dep_CustSetting cs WITH(NOLOCK)
					INNER JOIN customer ci WITH(NOLOCK) ON cs.custid = ci.custid
					CROSS APPLY (SELECT TOP 1 CASE WHEN @sporttype = 1 AND @Bettype <> 9 THEN maxpermatch
											WHEN @sporttype = 1 AND @Bettype = 9 THEN MaxPerMatch1MP
											WHEN @sporttype = 1 AND @Bettype = 99 THEN MaxPerMatch99
											WHEN @sporttype = 2 THEN maxpermatch2
											WHEN @sporttype = 3 THEN maxpermatch3
											WHEN @sporttype = 5 THEN maxpermatch5
											WHEN @sporttype = 8 THEN maxpermatch8
											WHEN @sporttype = 10 THEN maxpermatch10
											WHEN @sporttype = 11 THEN maxpermatch11
											WHEN @sporttype = 99 AND @Bettype = 9 THEN MaxPerMatch99MP
										END as MaxPerMatch	
								FROM custinfo c WITH(NOLOCK) 
								WHERE c.custid = ci.custid) b
				WHERE ci.srecommend = @custid
					AND ci.mrecommend NOT IN (SELECT custid FROM #DummyMaster)
					AND 1 = CASE WHEN (@AgentID = 0 OR (@AgentID <> 0 AND (ci.recommend = @AgentID OR roleid IN (3,4)))) THEN 1 
								ELSE 0 END	
					AND ci.username NOT LIKE '%CashOut%'
					AND ci.username  NOT LIKE '%OddsAdj%'
					AND ci.username  NOT LIKE '%ClearBal%'
					AND ci.username  NOT LIKE '%Bettrade%'
					AND sporttype = @sporttype
					AND bettype = @bettype
					AND 1 = CASE WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 0 AND @UpdateMPM = 0 AND @MinBet > MaxBet THEN 1
								WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 1 AND @UpdateMPM = 0 AND (@MaxBet < MinBet OR @MaxBet > b.MaxPerMatch) THEN 1
								WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 0 AND @UpdateMPM = 1 AND @MaxPerMatch < MaxBet THEN 1
								
								WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 1 AND @UpdateMPM = 0 AND (@MinBet > @MaxBet OR @MaxBet > b.MaxPerMatch) THEN 1
								WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 0 AND @UpdateMPM = 1 AND (@MinBet > MaxBet OR MaxBet > @MaxPerMatch) THEN 1
								WHEN @UpdateMinBet = 0 AND @UpdateMaxBet = 1 AND @UpdateMPM = 1 AND (Minbet > @MaxBet OR @MaxPerMatch < @MaxBet) THEN 1
								
								WHEN @UpdateMinBet = 1 AND @UpdateMaxBet = 1 AND @UpdateMPM = 1 AND (@MinBet > @MaxBet OR @MaxBet > @MaxPerMatch) THEN 1
								ELSE 0 END
				)
			BEGIN
				SELECT @ErrCode = 103,
					@ErrMsg = 'There are some customers having Bet Setting don''t follow the rule below. Please check again!'
				RETURN						
			END	
		END		
	END	
 END
 
 