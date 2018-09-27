/*<info serverAlias="DBCUST-CustDB" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_ExecRep_Cust_02]
	@IDs VARCHAR(MAX),
	@SBComm DECIMAL(9,8) ,
	@NGComm DECIMAL(9,8)=0,	
	@ParlayComm DECIMAL(9,8)=0,
	@IsUpdateNG BIT = 0
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
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
	- 20180924@Winnie: Remove Allbet [RedmineID: #99378]
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

END
GO