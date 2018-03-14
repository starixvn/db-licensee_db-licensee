/*<info serverAlias="DBCUST-CustDB" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_ExecRep_Cust_02]
	@IDs VARCHAR(MAX),
	@SBComm DECIMAL(9,8) ,
	@NGComm DECIMAL(9,8)=0,	
	@RacingComm DECIMAL(9,8)=0,
	@ParlayComm DECIMAL(9,8)=0,
	@AllbetComm DECIMAL(9,8)=0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRacing BIT = 0,
	@IsUpdateAllbet BIT = 0
AS
/*
Created: 20120730@Henry
Task : Update Licensee's players commission
DB: DBCUST/CustDB
Original: 

Revisions:
	- 20131023@Hannah: offer Live Casino commission
	- 20150610@Daniel: 
	    + Improve medthod check table existing in subscribers	
	    + Separate custDB to new server DBCUST 	
	- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
	- 20171201@Johnson: enhance AB comm setting, dont move individual setting if not change comm AB [Redmine: #87352]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	
Param's Explanation:
• @ErrCode:
    = 0: Transaction recorded successfully.
    > 0: Specific Error.
    
• @ErrMsg: Error description.
*/
BEGIN
	SET NOCOUNT ON;
	
	IF NOT(dbo.f_CheckRepTable('custinfo') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustSetting') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustSetting3rd') = 1 
		 AND dbo.f_CheckRepTable('CustSettingGame') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustDiscountSetting_Member') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustDiscountGroupSetting_Member') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustSettingMode') = 1 
	 )
		RETURN 


	DECLARE @res AS TABLE (custid INT)
	DECLARE @splitter CHAR(1), @string VARCHAR(MAX)

	SELECT @splitter = ',', @string = @IDs

	IF SUBSTRING (@string, LEN (@string), 1) <> @splitter
		  SET @string= @string+@splitter

	DECLARE @START INT, @word VARCHAR(4000), @CHARINDEX INT, @i INT
	
	SET @i=1
	SET @START=1
	SET @CHARINDEX= CHARINDEX( @splitter, @string, @START)
	
	WHILE (@CHARINDEX <> 0)BEGIN
		SET @word= SUBSTRING( @string, @START, @CHARINDEX - @START)
		SET @START= @CHARINDEX +1
		SET @CHARINDEX= CHARINDEX( @splitter, @string, @START)
		INSERT INTO @res  VALUES(CAST(@word AS INT))
		SET @i=@i+1
	END	

	UPDATE [dbo].Dep_CustSetting WITH (ROWLOCK, UPDLOCK)
	SET playerdiscount = @SBComm 
	WHERE custid IN (SELECT CustID FROM @res)  
		AND playerdiscount <> @SBComm  	
		AND bettype NOT IN (9,29)

	UPDATE [dbo].Dep_CustSetting WITH (ROWLOCK, UPDLOCK)
	SET playerdiscount = @ParlayComm
	WHERE custid IN (SELECT CustID FROM @res)  
		AND playerdiscount <>  @ParlayComm  	
		AND bettype   IN (9,29)
		
	IF (@IsUpdateNG=1) -- update Number Game
	BEGIN	
		UPDATE [dbo].Dep_CustSetting3rd WITH (ROWLOCK, UPDLOCK)
		SET playerdiscount = @NGComm 
		WHERE custid IN (SELECT CustID FROM @res)  
			AND playerdiscount <> @NGComm
			AND sporttype = 161  	
	END

	IF (@IsUpdateRacing=1) --update racing
	BEGIN
		UPDATE [dbo].Dep_CustSetting3rd WITH (ROWLOCK, UPDLOCK)
		SET playerdiscount = @RacingComm 
		WHERE custid IN (SELECT CustID FROM @res)
			AND playerdiscount <> @RacingComm
			AND sporttype IN (151,152,153)
	END		
	
	IF (@IsUpdateAllbet=1)
	BEGIN
		IF EXISTS(SELECT TOP 1 1 
					FROM dbo.Dep_CustSettingMode WITH(NOLOCK)
					WHERE CustID IN (SELECT custid FROM @res) AND isGroupedComm = 1)
		BEGIN
			DECLARE @AgentID INT 
			
			SELECT @AgentID = recommend 
			FROM dbo.CustInfo WITH(NOLOCK)
			WHERE custid IN (SELECT top 1 custid FROM @res)
			
			--check if setting change really or not before move
			IF EXISTS(SELECT 1
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					WHERE AgentID = @AgentID
						AND sporttype = 211
						AND bettype = 2401
						AND playerdiscount <> @AllbetComm
					)
			BEGIN		
				--move to individual setting
				INSERT INTO dbo.Dep_CustDiscountSetting_Member
					(CustID
					,SportType
					,BetType
					,PlayerDiscount
					,AgentDiscount
					,MasterDiscount
					,SuperDiscount)
				SELECT t.CustID
					,grp.SportType
					,grp.BetType
					,grp.PlayerDiscount
					,grp.AgentDiscount
					,grp.MasterDiscount
					,grp.SuperDiscount
				FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
				CROSS APPLY (SELECT custid
							FROM dbo.Dep_CustSettingMode WITH(NOLOCK)
							WHERE CustID IN (SELECT custid FROM @res) 
								AND isGroupedComm = 1) t
				LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) ON cs.custid = t.custid
																			AND cs.sporttype = grp.sporttype
																			AND cs.bettype = grp.bettype
				WHERE AgentID = @AgentID
					AND cs.custid IS NULL
				
				UPDATE dbo.Dep_CustSettingMode WITH(UPDLOCK,ROWLOCK)
				SET	isGroupedComm = 0		
				WHERE custid IN (SELECT custid FROM @res)
					AND isGroupedComm = 1
			END		
		END		
		
		UPDATE dbo.Dep_CustDiscountSetting_Member WITH(UPDLOCK,ROWLOCK)
		SET playerdiscount = @AllbetComm
		WHERE custid IN (SELECT custid FROM @res)
			AND sporttype = 211
			AND bettype = 2401
	END
END
GO