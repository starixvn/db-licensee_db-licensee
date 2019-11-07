/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,Dot_Member" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Dep_Customer_Archive_ReactiveCustomer]     
	@CustID int = 0,  
	@ReinitOldBalance BIT = 1,
	@CheckUniqueUsername2 BIT = 1,
	@ErrCode int = 0 OUTPUT,    
	@ErrMsg nvarchar(2000) = '' OUTPUT     
AS    

/*    
	Created: 20181010@Kean    
	Task :  The reactivation of archived deposit member include customer info and settings  [Redmind: #99882]
	DB: DBCUST/CustDB    
	Original: Reuse first deposit SP [Dot_Dep_CustomerInsMember_Ag_Cust] and edit  
	    
	Revisions:    
		- 20181010@Kean: First commit
		- 20181119@Dominic: Check betsetting Esports [Redmine: 100721]
		- 20181227@Dominic: Check if dormant member is archived completely
		- 20190305@Dominic: Add @CheckUniqueUsername2
	Param's Explanation:    
	? @CustID: return old deposit member CustID    
	? @ReinitOldBalance: flag to reinit old balance   
	    
	? @ErrCode:    
	 = 0: Transaction recorded successfully.    
	 > 0: Specific Error.    
	     
	? @ErrMsg: Error description.    
*/ 
BEGIN
	SET NOCOUNT ON    
	    
	declare @startRun datetime    
	declare @endRun datetime    
	declare @duration int    
	set @startRun = getdate()    
	    
	----- Elodie @ 01 JUN 2015 -------------------    
	 DECLARE @tmp_Sports TABLE (SportType SMALLINT, SportName NVARCHAR(50))    
	 DECLARE @tmp_GameType TABLE (GameTypeID INT, GameTypeName NVARCHAR(50), IsDisabled BIT, IBCBettypeID INT)    
	    
	 BEGIN TRY    
	  INSERT INTO @tmp_Sports (SportType, SportName)    
	  SELECT SportType, SportName FROM DBAGE.bodb02.dbo.Sports WITH (NOLOCK)      
	 END TRY    
	 BEGIN CATCH    
	  INSERT INTO @tmp_Sports (SportType, SportName)    
	  SELECT SportType, SportName FROM DBTXN.bodb02.dbo.Sports WITH (NOLOCK)     
	 END CATCH     
	    
	 BEGIN TRY      
	  INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)    
	  SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBAGE.bodb02.dbo.GameType WITH (NOLOCK)    
	 END TRY    
	 BEGIN CATCH      
	  INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)    
	  SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBTXN.bodb02.dbo.GameType WITH (NOLOCK)    
	 END CATCH    
	----- /Elodie @ 01 JUN 2015 -------------------    
	    
	---------------------------------    
	--20100922@Thien:   1st phrase - Get rid of members' information for Licensee site (first name, last name, email).    
	--                  Will remove these params once Brian's side removes the calling from Web code.
	--20181011@Kean: Support for reactivation of member
	--SELECT  @FirstName = '',    
	--		@LastName = '',    
	--		@Email = ''    
	---------------------------------
	    
	
	
	    
	declare @currency int,    
	 @recommend int,    
	 @mrecommend int,    
	 @srecommend int,     
	 @agusername varchar(30),    
	 @site varchar(30),    
	    
	 @pwdexpiry datetime,    
	 @ugroup varchar(5),    
	 @discount decimal(9,8),     
	 @discountcs decimal(9,8),    
	 @discount1x2 decimal(9,8),--1x2 agent comm     
	   
	 @playerdiscount decimal(9,8),    
	 @playerdiscountcs decimal(9,8),    
	 @playerdiscount1x2 decimal(9,8),--1x2 comm     
	
	     
	 --v161    
	 @v161playerdiscount decimal(9,8),-- number game com for player    
	    
	
	
	 --Keno    
	 @v202playerdiscount_1501 decimal(9,8),    
	
	 --Keno    
	 @v202discount_1501 DECIMAL(9,8),    
	    
	 @minbet money,     
	 @maxbet money,     
	 @maxpermatch money,     
	 @minbetv2 money,     
	 @maxbetv2 money,     
	 @maxpermatchv2 money,    
	    
	 @minbetv3 money,     
	 @maxbetv3 money,     
	 @maxpermatchv3 money,    
	    
	 @minbetv5 money,     
	 @maxbetv5 money,     
	 @maxpermatchv5 money,    
	    
	 @minbetv8 money,     
	 @maxbetv8 money,     
	 @maxpermatchv8 money,    
	    
	 @minbetv10 money,     
	 @maxbetv10 money,     
	 @maxpermatchv10 money,    
	    
	 @minbetv11 money,     
	 @maxbetv11 money,     
	 @maxpermatchv11 money,    
	 
	 @minbetv44 money,     
	 @maxbetv44 money,     
	 @maxpermatchv44 money, 
	

	 @minbetv99 money,     
	 @maxbetv99 money,     
	 @maxpermatchv99 money,    
	     
	 --Mix Parlay Mixed sports    
	 @minbetv99MP money,    
	 @maxbetv99MP money,    
	 @maxpermatchv99MP money,    
	     
	
	 --Number game    
	 @minbetv161 money,    
	 @maxbetv161 money,    
	 @maxperballv161 money,    
	 @maxpermatchv161 money    

	 --@Success bit    
	    
	Declare @apositiontaking_1 smallmoney,    
	 @apositiontaking_2 smallmoney,    
	 @apositiontaking_3 smallmoney,    
	 @apositiontaking_4 smallmoney,    
	 @apositiontaking_5 smallmoney,    
	 @apositiontaking_6 smallmoney,    
	 @apositiontaking_7 smallmoney,    
	 @apositiontaking_8 smallmoney,    
	  
	 @apositiontaking_9 smallmoney,    
	 @apositiontaking_10 smallmoney,    
	     
	 @alivepositiontaking_1 smallmoney,    
	 @alivepositiontaking_3 smallmoney,    
	 @alivepositiontaking_7 smallmoney,    
	 @alivepositiontaking_8 smallmoney,    
	     
	 @v2apositiontaking_1 smallmoney,    
	 @v2apositiontaking_2 smallmoney,    
	 @v2apositiontaking_3 smallmoney,    
	 @v2apositiontaking_7 smallmoney,    
	 @v2apositiontaking_8 smallmoney,    
	 --@v2apositiontaking_9 smallmoney,-- not use for baseket ball    
	 @v2apositiontaking_20 smallmoney,    
	     
	 @v3apositiontaking_1 smallmoney,    
	 @v3apositiontaking_2 smallmoney,    
	 @v3apositiontaking_3 smallmoney,    
	 @v3apositiontaking_20 smallmoney,    
	    
	 @v5apositiontaking_1 smallmoney,    
	 @v5apositiontaking_2 smallmoney,    
	 @v5apositiontaking_3 smallmoney,    
	 @v5apositiontaking_20 smallmoney,    
	    
	 @v8apositiontaking_1 smallmoney,    
	 @v8apositiontaking_3 smallmoney,    
	 @v8apositiontaking_20 smallmoney,    
	    
	 @v10apositiontaking_1 smallmoney,    
	 @v10apositiontaking_2 smallmoney,    
	 @v10apositiontaking_3 smallmoney,    
	 @v10apositiontaking_20 smallmoney,    
	    
	 @v11apositiontaking_1 smallmoney,    
	 @v11apositiontaking_20 smallmoney,     

	 @v44apositiontaking_3 smallmoney,    
	
	 @v99apositiontaking_1 smallmoney,    
	 @v99apositiontaking_2 smallmoney,    
	 @v99apositiontaking_3 smallmoney,    
	 @v99apositiontaking_9 smallmoney,-- parlay mixed sports    
	 @v99apositiontaking_20 smallmoney,    
	
	 --positionataking for number game    
	 @v161apositiontaking_81 smallmoney,    
	 @v161apositiontaking_83 smallmoney,    
	 @v161apositiontaking_86 smallmoney,    
	 @v161apositiontaking_88 smallmoney,    
	     
	 @v161alivepositiontaking_85 smallmoney,    
	 @v161alivepositiontaking_86 smallmoney,    
	 @v161alivepositiontaking_87 smallmoney,    
	 @v161alivepositiontaking_89 smallmoney,    
	 @v161alivepositiontaking_90 smallmoney,    

	 --Keno    
	 @v202apositiontaking_1501 smallmoney
	    
	 
	     
	declare @transcode bigint,     
	 @MinMinBet money, @MaxMaxBet money, @MaxMaxPerMatch money,    
	 @MinMinBetv2 money, @MaxMaxBetv2 money, @MaxMaxPerMatchv2 money,    
	 @MinMinBetv3 money, @MaxMaxBetv3 money, @MaxMaxPerMatchv3 money,    
	 @MinMinBetv5 money, @MaxMaxBetv5 money, @MaxMaxPerMatchv5 money,    
	 @MinMinBetv8 money, @MaxMaxBetv8 money, @MaxMaxPerMatchv8 money,    
	 @MinMinBetv10 money, @MaxMaxBetv10 money, @MaxMaxPerMatchv10 money,    
	 @MinMinBetv11 money, @MaxMaxBetv11 money, @MaxMaxPerMatchv11 money,    
	 @MinMinBetv44 money, @MaxMaxBetv44 money, @MaxMaxPerMatchv44 money,  

	     
	 @MinMinBetv99 money, @MaxMaxBetv99 money, @MaxMaxPerMatchv99 money,     
	     
	 --Mix parlay mix sport    
	 @MinMinBetv99MP money, @MaxMaxBetv99MP money, @MaxMaxPerMatchv99MP money,    
	
	 --Number game    
	 @MinMinBetv161 money, @MaxMaxBetv161 money, @MaxMaxPerMatchv161 money, @MaxMaxPerBallv161 money,    
	    
	 @AgentCredit money, @Credit_AllOtherMember money, @Aclosed bit,    
	 @MaxCredit_Mem money,    
	 @Asuspended bit,    
	-- @AgentMaxPerMatch money, @AgentMaxPerMatchb money,    
	-- @MaxPerMatch_AllOtherMember money, @MaxPerMatchv2_AllOtherMember money,    
	    
	 --m2    
	 @mpositiontaking_1 smallmoney,    
	 @mpositiontaking_2 smallmoney,    
	 @mpositiontaking_3 smallmoney,    
	 @mpositiontaking_4 smallmoney,    
	 @mpositiontaking_5 smallmoney,    
	 @mpositiontaking_6 smallmoney,    
	 @mpositiontaking_7 smallmoney,    
	 @mpositiontaking_8 smallmoney,    
	 @mpositiontaking_9 smallmoney,    
	 @mpositiontaking_10 smallmoney,    
	 @mlivepositiontaking_1 smallmoney,    
	 @mlivepositiontaking_3 smallmoney,    
	 @mlivepositiontaking_7 smallmoney,    
	 @mlivepositiontaking_8 smallmoney,    
	     
	 @v2mpositiontaking_1 smallmoney,    
	 @v2mpositiontaking_2 smallmoney,    
	 @v2mpositiontaking_3 smallmoney,    
	 @v2mpositiontaking_7 smallmoney,    
	 @v2mpositiontaking_8 smallmoney,    
	 --@v2mpositiontaking_9 smallmoney,-- not use     
	 @v2mpositiontaking_20 smallmoney,    
	    
	 @v3mpositiontaking_1 smallmoney,    
	 @v3mpositiontaking_2 smallmoney,    
	 @v3mpositiontaking_3 smallmoney,    
	 @v3mpositiontaking_20 smallmoney,    
	    
	 @v5mpositiontaking_1 smallmoney,    
	 @v5mpositiontaking_2 smallmoney,    
	 @v5mpositiontaking_3 smallmoney,    
	 @v5mpositiontaking_20 smallmoney,    
	    
	 @v8mpositiontaking_1 smallmoney,    
	 @v8mpositiontaking_3 smallmoney,    
	 @v8mpositiontaking_20 smallmoney,    
	    
	 @v10mpositiontaking_1 smallmoney,    
	 @v10mpositiontaking_2 smallmoney,    
	 @v10mpositiontaking_3 smallmoney,    
	 @v10mpositiontaking_20 smallmoney,    
	    
	 @v11mpositiontaking_1 smallmoney,    
	    
	 @v11mpositiontaking_20 smallmoney,    
	 
	 @v44mpositiontaking_3 smallmoney, 
	 
	 @v99mpositiontaking_1 smallmoney,    
	 @v99mpositiontaking_2 smallmoney,    
	 @v99mpositiontaking_3 smallmoney,    
	 @v99mpositiontaking_9 smallmoney,-- mix parlay mixed sports    
	 @v99mpositiontaking_20 smallmoney,    
	
	 --for number game    
	 @v161mpositiontaking_81 smallmoney,    
	 @v161mpositiontaking_83 smallmoney,    
	 @v161mpositiontaking_86 smallmoney,    
	 @v161mpositiontaking_88 smallmoney,    
	 @v161mlivepositiontaking_85 smallmoney,    
	 @v161mlivepositiontaking_86 smallmoney,    
	 @v161mlivepositiontaking_87 smallmoney,    
	 @v161mlivepositiontaking_89 smallmoney,    
	 @v161mlivepositiontaking_90 smallmoney,    

	 --Keno    
	 @v202mpositiontaking_1501 smallmoney,    
	     
	 --s3    
	 @spositiontaking_1 smallmoney,    
	 @spositiontaking_2 smallmoney,    
	 @spositiontaking_3 smallmoney,    
	 @spositiontaking_4 smallmoney,    
	 @spositiontaking_5 smallmoney,    
	 @spositiontaking_6 smallmoney,    
	 @spositiontaking_7 smallmoney,    
	 @spositiontaking_8 smallmoney,    
	 @spositiontaking_9 smallmoney,    
	 @spositiontaking_10 smallmoney,    
	     
	 @slivepositiontaking_1 smallmoney,    
	 @slivepositiontaking_3 smallmoney,    
	 @slivepositiontaking_7 smallmoney,    
	 @slivepositiontaking_8 smallmoney,    
	     
	 @v2spositiontaking_1 smallmoney,    
	 @v2spositiontaking_2 smallmoney,    
	 @v2spositiontaking_3 smallmoney,    
	 @v2spositiontaking_7 smallmoney,    
	 @v2spositiontaking_8 smallmoney,    
	 --@v2spositiontaking_9 smallmoney, -- not use for baseket ball    
	 @v2spositiontaking_20 smallmoney,    
	     
	 @v3spositiontaking_1 smallmoney,    
	 @v3spositiontaking_2 smallmoney,    
	 @v3spositiontaking_3 smallmoney,    
	 @v3spositiontaking_20 smallmoney,    
	    
	 @v5spositiontaking_1 smallmoney,    
	 @v5spositiontaking_2 smallmoney,    
	 @v5spositiontaking_3 smallmoney,    
	 @v5spositiontaking_20 smallmoney,    
	    
	 @v8spositiontaking_1 smallmoney,    
	 @v8spositiontaking_3 smallmoney,    
	 @v8spositiontaking_20 smallmoney,    
	    
	 @v10spositiontaking_1 smallmoney,    
	 @v10spositiontaking_2 smallmoney,    
	 @v10spositiontaking_3 smallmoney,    
	 @v10spositiontaking_20 smallmoney,    
	    
	 @v11spositiontaking_1 smallmoney,    
	 @v11spositiontaking_20 smallmoney,    
	 
	  @v44spositiontaking_3 smallmoney,   

	    
	 @v99spositiontaking_1 smallmoney,    
	 @v99spositiontaking_2 smallmoney,    
	 @v99spositiontaking_3 smallmoney,    
	 @v99spositiontaking_9 smallmoney,-- mix parlay mixed sports    
	 @v99spositiontaking_20 smallmoney,    
	
	 @v161spositiontaking_81 smallmoney,    
	 @v161spositiontaking_83 smallmoney,    
	 @v161spositiontaking_86 smallmoney,    
	 @v161spositiontaking_88 smallmoney,    
	     
	 @v161slivepositiontaking_85 smallmoney,    
	 @v161slivepositiontaking_86 smallmoney,    
	 @v161slivepositiontaking_87 smallmoney,    
	 @v161slivepositiontaking_89 smallmoney,     
	 @v161slivepositiontaking_90 smallmoney,     

	 --Keno    
	 @v202spositiontaking_1501 smallmoney,    
	      
	 @adiscount decimal(9,8),    
	 @adiscountcs decimal(9,8),    
	 @adiscount1x2 decimal(9,8),--1x2 master comm     
	
	    
	 @sdiscount decimal(9,8),    
	 @sdiscountcs decimal(9,8),    
	 @sdiscount1x2 decimal(9,8),--1x2 super comm    
	
	    
	 @maxdiscount decimal(9,8),    
	 @maxdiscountcs decimal(9,8),    
	
	     
	 --v161    
	 @v161discount decimal(9,8),    
	 @v161adiscount decimal(9,8),    
	 @v161sdiscount decimal(9,8),    
	
	 --Keno    
	 @v202adiscount_1501 decimal(9,8),    
	 @v202sdiscount_1501 decimal(9,8),    
	 @DisableNumber bit,-- for number game    
	 
	 @DoubleCommLosing BIT,-- double comm losing status    
	 @DisableCasinoBonus BIT,    

	
	 @HideKeno BIT,    
	    
	 @suspendedFlag varchar(6),    
	 @suspended bit,    
	    
	 @matchlimit smallmoney,    
	 @virtualmultiplier smallmoney    
	    
	--20140422@Johnson: hardcode bet limit for keno    
	Declare @custgametype table(gametypeid int, maxbet money, maxpergametype money)    
	    
	--Init param    
	select @ErrCode = 0,    
	 @ErrMsg = '',    
	 @pwdexpiry = dateadd(dd, 30, getdate())  

	    
	----------------Affiliate Bonus Code---------------------
	--20181011@Kean: Support for reactivation of member
	/*    
	IF (isnull(@AffiliateID, 0) = 0 AND @BonusCode is not null)     
	BEGIN     
	 select @AffiliateID = AffID from DBAFF12BET.[Affiliate_12Bet].dbo.AffDetail with(nolock) where bonuscode = @BonusCode     
	 if isnull(@AffiliateID,0) > 0 -- @bonuscode is valid, change currency agent from [..]01 --> [..]02    
	 BEGIN    
	  declare @_currAgentName varchar(20)    
	  select @_currAgentName =username from Custinfo with(nolock) where custid=@AgentID         
	  select @AgentID = CustID from CustInfo with(nolock) where username = Replace(@_currAgentName, '01', '02')     
	 END     
	END 
	*/   
	------------------------------------------------------- 
	   
	---------------------------------
	--20181011@Kean: Support for reactivation of member
	DECLARE @FirstName nvarchar(50),    
			@LastName nvarchar(50),    
			@Email nvarchar(50),    
			@username2 varchar(50),    
			@refcode2 nvarchar(50),    
			@Password varchar(40),
			@AgentID int,
			@Country nvarchar(50),
			@Username varchar(50) ='',
			@phone nvarchar(50),
			@mobilephone nvarchar(50),
			@fax nvarchar(50),
			@address nvarchar(50),
			@city nvarchar(50),   
			@state nvarchar(50),
			@postal nvarchar(50),
			@birthday smalldatetime,
			@refcode1	nvarchar(50),
			@remark nvarchar(50),
			@createDate smalldatetime,
			-- Use for reinit old balance
			@CustIDBalanceDummy INT,
			@ClosingBalance MONEY

	EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
			, @Action='REACTIVATION'
			, @Status='OnProgress'
			, @Message= 'Start reactivating customer'

	SELECT @FirstName = firstname,
				@Lastname = lastname,
				@Username = username,
				@Password = userpwd,
				@pwdexpiry = pwdexpiry,
				@phone = phone,
				@mobilephone = mobilephone,
				@Email = email,
				@fax = fax,
				@address = address,
				@city = city,
				@state = state,
				@Country = country,
				@postal = postal,
				@birthday = birthday,
				@refcode1 = refcode1,
				@remark = remark,
				@createDate = creatdate,
				@username2 = username2,
				@refcode2 = refcode2,
				@AgentID = recommend
	 FROM DBARCCUST.Bodb_Archive_Customer_Licensee.dbo.Customer WITH(NOLOCK)
	 WHERE custid = @CustID

	--Check exist custid
	IF ISNULL(@Username,'') = ''      
	BEGIN    
		SELECT @ErrMsg = 'This account is not a dormant member.', @ErrCode = 7
		
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'This member does not exist in Archive DB'

		RETURN    
	END 

	--Check if this member is archived completely
	IF NOT EXISTS(SELECT 1 FROM Dep_Customer_Archived (NOLOCK) WHERE CustID=@CustID AND Status='completed')
	BEGIN    
		SELECT @ErrMsg = 'This account is locked for Archive Process now. Please try again after few minutes.', @ErrCode = 8
		
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'This member is not archived completely, can not be reactivated.'

		RETURN    
	END 

	--Check if this member is reactivated by someone else
	IF EXISTS (SELECT 1 FROM Customer (NOLOCK) WHERE CustID=@CustID)
	OR EXISTS (SELECT 1 FROM Custinfo (NOLOCK) WHERE CustID=@CustID)
	BEGIN
		SELECT @ErrMsg = 'This account has been reactivated by someone else.', @ErrCode = 9
		
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'This member is existing in Main DB.'

		RETURN    
	END
	---------------------------------
	    
	select    
	 @srecommend = ci.srecommend,    
	 @mrecommend = ci.mrecommend,     
	 @recommend = ci.custID,    
	 @agusername = ci.username,    
	 @currency = ci.currency,     
	 @maxpermatch = maxpermatch,    
	 @maxpermatchv2 = maxpermatch2,    
	 @maxpermatchv3 = maxpermatch3,    
	 @maxpermatchv5 = maxpermatch5,    
	 @maxpermatchv8 = maxpermatch8,    
	 @maxpermatchv10 = maxpermatch10,    
	 @maxpermatchv11 = maxpermatch11,    
	 @maxpermatchv44 = maxpermatch44,
  
	 @maxpermatchv161 = maxpermatch161,--number game    
	 @maxperballv161 = maxperball161,    
	 @maxpermatchv99MP = maxpermatch99mp, -- mix parlay mix sports    
	 @maxpermatchv99 = maxpermatch99,    

	 ----- add more    
	 @site    = c.site,    
	 @AgentCredit  = IsNull(Credit, 0),    
	 @Aclosed   = closed,    
	 @Asuspended   = reject,    
	 @matchlimit   = matchlimit,    
	 @virtualmultiplier = virtualmultiplier,    
	
	
	 @DisableNumber  = ISNULL(DisableNumber,0),    
	 @DoubleCommLosing = DoubleCommLosing,    
	 @DisableCasinoBonus = 1, --20130805@Elodie hardcode    
	 @HideKeno = HideKeno    
	FROM custinfo ci WITH(NOLOCK)     
	 inner join customer c WITH(NOLOCK) ON ci.custid = c.custid    
	WHERE ci.CustID = @AgentID    
	 and ci.roleid = 2    
	     
	--check valid agent here    
	IF @recommend is null    
	BEGIN    
		SELECT @ErrMsg = 'Invalid agent.', @ErrCode = 10    
	 
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'Agent of this member does not exist in custinfo in main DB'

		RETURN    
	END    
	    
	--20110419@Thien: hard-code the ugroup for licensee sites    
	--SELECT @ugroup = case @site when 'DELA' then 'd' else 'a' end    
	    
	--20110426@Thien: rollback for DELA, set to group A again    
	SELECT @ugroup = 'a'    
	    
	--20110916@Thien: Hard-code the ugroup for Alog.    
	--     Adjust all USD, EUR and GBP currency members to 6 pts line (group B), apply this to all existing and future members    
	---20141103@Jim: just Alog member belong to currency US$ and GBP need to set  to  group D as default (exclude  EUR currency member)    
	--20131230@Jim: Hard-code the ugroup for Asiabet88     
	--     Adjust all USD, EUR  currency members to 6 pts line (group B), apply this to all existing and future members    
	--20141103@Jim: fix bug alog member's ugroup are wrong      
	--20141212@Jamie: Set ugroup = a for Alog (USD,GBP) [redmine:#25577]    
	--20150928@Victor: Set uGroup = C for all new Asiabet88 KRW members [redmine: 44141]
	-- 20180222@Elodie: Set uGroup = C for all new AE88 RMB members [Redmine: #90965]  
	/*SELECT @ugroup = 
	CASE	WHEN @site = 'Asiabet88' AND  @currency IN (3,6) THEN 'b' 	
			WHEN @site = 'Asiabet88' AND @currency = 45 THEN 'c'		
			WHEN @site = 'Ae88' AND @currency = 13 THEN 'b'			
			ELSE 'a'    
	END*/

	IF EXISTS (SELECT TOP 1 1 FROM Dep_DefaultOddGroup WITH(NOLOCK) WHERE AgentID=@AgentID AND IsActive=1)
		SELECT @ugroup = Ugroup FROM Dep_DefaultOddGroup WITH(NOLOCK) WHERE AgentID=@AgentID AND IsActive=1
	     
	--Will check the usergroup here    
	--MinBet, MaxBet, Commission get from CA Agent    
	    
	           
	           
	SELECT  @minbet  = MAX(CASE WHEN sporttype = 1 AND bettype = 1 THEN minbet ELSE 0 END)    
	  ,@maxbet  = MAX(CASE WHEN sporttype = 1 AND bettype = 1 THEN maxbet ELSE 0 END)    
	  ,@minbetv2  = MAX(CASE WHEN sporttype = 2 AND bettype = 1 THEN minbet ELSE 0 END)    
	  ,@maxbetv2  = MAX(CASE WHEN sporttype = 2 AND bettype = 1 THEN maxbet ELSE 0 END)    
	  ,@minbetv3  = MAX(CASE WHEN sporttype = 3 AND bettype = 1 THEN minbet ELSE 0 END)    
	  ,@maxbetv3  = MAX(CASE WHEN sporttype = 3 AND bettype = 1 THEN maxbet ELSE 0 END)    
	  ,@minbetv5  = MAX(CASE WHEN sporttype = 5 AND bettype = 1 THEN minbet ELSE 0 END)    
	  ,@maxbetv5  = MAX(CASE WHEN sporttype = 5 AND bettype = 1 THEN maxbet ELSE 0 END)    
	  ,@minbetv8  = MAX(CASE WHEN sporttype = 8 AND bettype = 1 THEN minbet ELSE 0 END)    
	  ,@maxbetv8  = MAX(CASE WHEN sporttype = 8 AND bettype = 1 THEN maxbet ELSE 0 END)    
	  ,@minbetv10  = MAX(CASE WHEN sporttype = 10 AND bettype =1 THEN minbet ELSE 0 END)    
	  ,@maxbetv10  = MAX(CASE WHEN sporttype = 10 AND bettype =1 THEN maxbet ELSE 0 END)    
	  ,@minbetv11  = MAX(CASE WHEN sporttype = 11 AND bettype =1 THEN minbet ELSE 0 END)    
	  ,@maxbetv11  = MAX(CASE WHEN sporttype = 11 AND bettype =1 THEN maxbet ELSE 0 END)    
	  ,@minbetv44  = MAX(CASE WHEN sporttype = 44 AND bettype =3 THEN minbet ELSE 0 END)    
	  ,@maxbetv44  = MAX(CASE WHEN sporttype = 44 AND bettype =3 THEN maxbet ELSE 0 END)
	  ,@minbetv99  = MAX(CASE WHEN sporttype = 99 AND bettype =1 THEN minbet ELSE 0 END)    
	  ,@maxbetv99  = MAX(CASE WHEN sporttype = 99 AND bettype =1 THEN maxbet ELSE 0 END)    
	  ,@minbetv99MP = MAX(CASE WHEN sporttype = 99 AND bettype =9 THEN minbet ELSE 0 END)    
	  ,@maxbetv99MP = MAX(CASE WHEN sporttype = 99 AND bettype =9 THEN maxbet ELSE 0 END)    
	
	  ,@discount  = MAX(CASE WHEN sporttype = 1 AND bettype = 1 THEN discount ELSE 0 END)    
	  ,@discountcs = MAX(CASE WHEN sporttype = 1 AND bettype = 4 THEN discount ELSE 0 END)    
	  ,@discount1x2 = MAX(CASE WHEN sporttype = 1 AND bettype = 5 THEN discount ELSE 0 END)    
	
	FROM Dep_Custsetting WITH(NOLOCK)    
	WHERE custid = @recommend AND islive=0    
	 AND bettype IN (1,3,4,5,9) AND sporttype IN (1,2,3,5,8,10,11,44,99)    
	    
	    
	SELECT  
	   @minbetv161  = MAX(CASE WHEN sporttype = 161 AND bettype = 81 THEN minbet ELSE 0 END)    
	  ,@maxbetv161  = MAX(CASE WHEN sporttype = 161 AND bettype = 81 THEN maxbet ELSE 0 END)      
	  ,@v161discount  = MAX(CASE WHEN sporttype = 161 AND bettype = 81 THEN discount ELSE 0 END)    
	FROM Dep_CustSetting3rd WITH(NOLOCK)    
	WHERE custid = @recommend AND islive=0    
	 AND bettype =81 AND sporttype =161
	
	---  Keno    
	SELECT @v202discount_1501 = MAX(CASE WHEN sporttype = 202 AND bettype = 1501 THEN discount ELSE 0 END)    
	FROM custsettinggame WITH(NOLOCK)    
	WHERE custid = @recommend and bettype = 1501 and sporttype =202  
	    
	DECLARE @vMaxbet money,     
	  @vMaxpermatch money    
	SELECT @vMaxbet = 0, @vMaxpermatch = 0 -- assign the default value    
	    
	/*    
	-- NumberGame - Hard code MaxBet and MaxPerBall    
	Kiwi@20120327: Rollback Number Game MaxBet and MaxperBall    
	Currency    Revise Max per bet  Revise Max per Ball    
	IN          5000                15000    
	RM          2000                5000    
	RMB         3000                10000    
	TB          20000               50000    
	*/    
	    
	-- HardCode -      
	    
	    
	IF(EXISTS(SELECT top 1 1 FROM Dep_CustBetLimit_Special WITH(NOLOCK) WHERE AgentID=@AgentID))    
	BEGIN    
	 SELECT @Maxbet    = ISNULL(MAX(CASE WHEN SportType = 1 AND Bettype = 1 THEN MaxBet ELSE NULL END),@Maxbet),     
	   @Maxpermatch  = ISNULL(MAX(CASE WHEN SportType = 1 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@Maxpermatch),    
	   @maxbetv2   = ISNULL(MAX(CASE WHEN SportType = 2 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv2),     
	   @maxpermatchv2  = ISNULL(MAX(CASE WHEN SportType = 2 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv2),    
	   @maxbetv3   = ISNULL(MAX(CASE WHEN SportType = 3 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv3),     
	   @maxpermatchv3  = ISNULL(MAX(CASE WHEN SportType = 3 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv3),    
	   @maxbetv5   = ISNULL(MAX(CASE WHEN SportType = 5 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv5),     
	   @maxpermatchv5  = ISNULL(MAX(CASE WHEN SportType = 5 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv5),    
	   @maxbetv8   = ISNULL(MAX(CASE WHEN SportType = 8 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv8),     
	   @maxpermatchv8  = ISNULL(MAX(CASE WHEN SportType = 8 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv8),    
	   @maxbetv10   = ISNULL(MAX(CASE WHEN SportType = 10 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv10),     
	   @maxpermatchv10  = ISNULL(MAX(CASE WHEN SportType = 10 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv10),    
	   @maxbetv11   = ISNULL(MAX(CASE WHEN SportType = 11 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv11),     
	   @maxpermatchv11  = ISNULL(MAX(CASE WHEN SportType = 11 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv11),  
	   @maxbetv44   = ISNULL(MAX(CASE WHEN SportType = 44 AND Bettype = 3 THEN MaxBet ELSE NULL END),@maxbetv44),     
	   @maxpermatchv44  = ISNULL(MAX(CASE WHEN SportType = 44 AND Bettype = 3 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv44), 
	   @maxbetv99   = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv99),     
	   @maxpermatchv99  = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv99),    
	   @maxbetv99MP  = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 9 THEN MaxBet ELSE NULL END),@maxbetv99MP),     
	   @maxpermatchv99MP = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 9 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv99MP),    
	  
	   @maxbetv161   = ISNULL(MAX(CASE WHEN SportType=161 THEN MaxBet END),@maxbetv161),     
	   @maxpermatchv161 = ISNULL(MAX(CASE WHEN SportType=161 THEN Maxpermatch END),@maxpermatchv161),     
	   @maxperballv161  = ISNULL(MAX(CASE WHEN SportType=161 THEN MaxPerBall END),@maxperballv161)
	   
	 FROM Dep_CustBetLimit_Special WITH(NOLOCK)     
	 WHERE AgentID = @AgentID    
	END     
	ELSE    
	BEGIN    
	 SELECT @Maxbet    = ISNULL(MAX(CASE WHEN SportType = 1 AND Bettype = 1 THEN MaxBet ELSE NULL END),@Maxbet),     
	  @Maxpermatch   = ISNULL(MAX(CASE WHEN SportType = 1 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@Maxpermatch),    
	  @maxbetv2    = ISNULL(MAX(CASE WHEN SportType = 2 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv2),     
	  @maxpermatchv2   = ISNULL(MAX(CASE WHEN SportType = 2 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv2),    
	  @maxbetv3    = ISNULL(MAX(CASE WHEN SportType = 3 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv3),     
	  @maxpermatchv3   = ISNULL(MAX(CASE WHEN SportType = 3 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv3),    
	  @maxbetv5    = ISNULL(MAX(CASE WHEN SportType = 5 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv5),     
	  @maxpermatchv5   = ISNULL(MAX(CASE WHEN SportType = 5 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv5),    
	  @maxbetv8    = ISNULL(MAX(CASE WHEN SportType = 8 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv8),     
	  @maxpermatchv8   = ISNULL(MAX(CASE WHEN SportType = 8 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv8),    
	  @maxbetv10    = ISNULL(MAX(CASE WHEN SportType = 10 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv10),     
	  @maxpermatchv10   = ISNULL(MAX(CASE WHEN SportType = 10 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv10),    
	  @maxbetv11    = ISNULL(MAX(CASE WHEN SportType = 11 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv11),     
	  @maxpermatchv11   = ISNULL(MAX(CASE WHEN SportType = 11 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv11),   
	  @maxbetv44    = ISNULL(MAX(CASE WHEN SportType = 44 AND Bettype = 3 THEN MaxBet ELSE NULL END),@maxbetv44),     
	  @maxpermatchv44   = ISNULL(MAX(CASE WHEN SportType = 44 AND Bettype = 3 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv44),   
	  @maxbetv99    = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv99),     
	  @maxpermatchv99   = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 1 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv99),    
	  @maxbetv99MP   = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 9 THEN MaxBet ELSE NULL END),@maxbetv99MP),     
	  @maxpermatchv99MP  = ISNULL(MAX(CASE WHEN SportType = 99 AND Bettype = 9 THEN  MaxPerMatch ELSE NULL END),@maxpermatchv99MP),    
	   
	  @maxbetv161    = ISNULL(MAX(CASE WHEN SportType = 161 AND Bettype = 1 THEN MaxBet ELSE NULL END),@maxbetv161),    
	  @maxpermatchv161  = ISNULL(MAX(CASE WHEN SportType = 161 AND Bettype = 1 THEN MaxPerMatch ELSE NULL END),@maxpermatchv161),    
	  @maxperballv161   = ISNULL(MAX(CASE WHEN SportType = 161 AND Bettype = 1 THEN MaxPerBall ELSE NULL END),@maxperballv161)
	  
	 FROM Dep_CustBetLimit_Special WITH(NOLOCK) WHERE Site=@site AND CurrencyID=@currency AND AgentID IS NULL    
	END    
	    
	    
	INSERT INTO @custgametype(gametypeid, maxbet, maxpergametype)    
	SELECT gametypeid, maxbet, maxpergametype     
	FROM Dep_CustBetLimitGameType_Special WITH (NOLOCK)     
	WHERE site = @site AND currencyid=@currency    
	    
	    
	--End Hardcode   
	select    
	 @playerdiscount = 0,    
	 @playerdiscountcs = 0,    
	 @playerdiscount1x2 = 0,  
	
	 @v161playerdiscount= 0, -- for number game    

	 --Keno    
	 @v202playerdiscount_1501 = 0    
	    
	--Position Taking get from Affilate Account
	--20181011@Kean: Support for reactivation of member
	/*    
	if isnull(@AffiliateID,0) > 0    
	BEGIN    
	 if NOT exists(select 1 from DBAFF12BET.[Affiliate_12Bet].dbo.AffInfo with(nolock) where AffID = @AffiliateID)      
	 BEGIN    
	  Select @ErrMsg = 'Invalid Affiliate agent.', @ErrCode = 12    
	  return    
	 END     
	END 
	*/    
	    
	    
	SELECT  @apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_4 = MAX(CASE WHEN bettype = 4 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_5 = MAX(CASE WHEN bettype = 5 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_6 = MAX(CASE WHEN bettype = 6 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_7 = MAX(CASE WHEN bettype = 7 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_8 = MAX(CASE WHEN bettype = 8 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_9 = MAX(CASE WHEN bettype = 9 AND sporttype = 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@apositiontaking_10= MAX(CASE WHEN bettype = 10 AND sporttype= 1 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	      
	  ,@mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_4 = MAX(CASE WHEN bettype = 4 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_5 = MAX(CASE WHEN bettype = 5 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_6 = MAX(CASE WHEN bettype = 6 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_7 = MAX(CASE WHEN bettype = 7 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_8 = MAX(CASE WHEN bettype = 8 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_9 = MAX(CASE WHEN bettype = 9 AND sporttype = 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@mpositiontaking_10= MAX(CASE WHEN bettype = 10 AND sporttype= 1 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	      
	  ,@alivepositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 1 AND isLive = 1 THEN apositiontaking ELSE 0 END)    
	  ,@alivepositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 1 AND isLive = 1 THEN apositiontaking ELSE 0 END)    
	  ,@alivepositiontaking_7 = MAX(CASE WHEN bettype = 7 AND sporttype = 1 AND isLive = 1 THEN apositiontaking ELSE 0 END)    
	  ,@alivepositiontaking_8 = MAX(CASE WHEN bettype = 8 AND sporttype = 1 AND isLive = 1 THEN apositiontaking ELSE 0 END)    
	      
	  ,@mlivepositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 1 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	  ,@mlivepositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 1 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	  ,@mlivepositiontaking_7 = MAX(CASE WHEN bettype = 7 AND sporttype = 1 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	  ,@mlivepositiontaking_8 = MAX(CASE WHEN bettype = 8 AND sporttype = 1 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	      
	  ,@v2apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 2 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v2apositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 2 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v2apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 2 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v2apositiontaking_7 = MAX(CASE WHEN bettype = 7 AND sporttype = 2 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v2apositiontaking_8 = MAX(CASE WHEN bettype = 8 AND sporttype = 2 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v2apositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 2 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	      
	  ,@v2mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 2 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@v2mpositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 2 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v2mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 2 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v2mpositiontaking_7 = MAX(CASE WHEN bettype = 7 AND sporttype = 2 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v2mpositiontaking_8 = MAX(CASE WHEN bettype = 8 AND sporttype = 2 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v2mpositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 2 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	      
	  ,@v3apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 3 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v3apositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 3 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v3apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 3 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	  ,@v3apositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 3 AND isLive = 0 THEN apositiontaking ELSE 0 END)    
	      
	  ,@v3mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 3 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@v3mpositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 3 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@v3mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 3 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@v3mpositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 3 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	      
	  ,@v5apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 5 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	  ,@v5apositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 5 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	  ,@v5apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 5 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	  ,@v5apositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 5 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	      
	  ,@v5mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 5 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v5mpositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 5 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@v5mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 5 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	  ,@v5mpositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 5 AND isLive = 0 THEN mpositiontaking ELSE 0 END)    
	      
	  ,@v8apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 8 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v8apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 8 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	  ,@v8apositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 8 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	    
	  ,@v8mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 8 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v8mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 8 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v8mpositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 8 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	      
	  ,@v10apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 10 AND isLive = 0 THEN apositiontaking ELSE 0 END)       
	  ,@v10apositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 10 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v10apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 10 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v10apositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 10 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	      
	  ,@v10mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 10 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v10mpositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 10 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v10mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 10 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v10mpositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 10 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	      
	  ,@v11apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 11 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v11apositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 11 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  
	  ,@v44apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 44 AND isLive = 0 THEN apositiontaking ELSE 0 END) 
	  
	  ,@v11mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 11 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v11mpositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 11 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v44mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 44 AND isLive = 0 THEN mpositiontaking ELSE 0 END)   
	  ,@v99apositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 99 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v99apositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 99 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v99apositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 99 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v99apositiontaking_9 = MAX(CASE WHEN bettype = 9 AND sporttype = 99 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	  ,@v99apositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 99 AND isLive = 0 THEN apositiontaking ELSE 0 END)      
	      
	  ,@v99mpositiontaking_1 = MAX(CASE WHEN bettype = 1 AND sporttype = 99 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v99mpositiontaking_2 = MAX(CASE WHEN bettype = 2 AND sporttype = 99 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v99mpositiontaking_3 = MAX(CASE WHEN bettype = 3 AND sporttype = 99 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v99mpositiontaking_9 = MAX(CASE WHEN bettype = 9 AND sporttype = 99 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	  ,@v99mpositiontaking_20= MAX(CASE WHEN bettype = 20 AND sporttype= 99 AND isLive = 0 THEN mpositiontaking ELSE 0 END)      
	    
	 
	FROM Dep_Custsetting WITH(NOLOCK)    
	WHERE custid = @recommend and bettype IN (1,2,3,4,5,6,7,8,9,10,20) and sporttype IN (1,2,3,5,8,10,11,44,99)    
	    
	    
	SELECT 
	   @v161apositiontaking_81 = MAX(CASE WHEN bettype = 81 AND sporttype = 161 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	  ,@v161apositiontaking_83 = MAX(CASE WHEN bettype = 83 AND sporttype = 161 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	  ,@v161apositiontaking_86 = MAX(CASE WHEN bettype = 86 AND sporttype = 161 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	  ,@v161apositiontaking_88 = MAX(CASE WHEN bettype = 88 AND sporttype = 161 AND isLive = 0 THEN apositiontaking ELSE 0 END)     
	      
	  ,@v161mpositiontaking_81 = MAX(CASE WHEN bettype = 81 AND sporttype = 161 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v161mpositiontaking_83 = MAX(CASE WHEN bettype = 83 AND sporttype = 161 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v161mpositiontaking_86 = MAX(CASE WHEN bettype = 86 AND sporttype = 161 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	  ,@v161mpositiontaking_88 = MAX(CASE WHEN bettype = 88 AND sporttype = 161 AND isLive = 0 THEN mpositiontaking ELSE 0 END)     
	      
	  ,@v161alivepositiontaking_85 = MAX(CASE WHEN bettype = 85 AND sporttype = 161 AND isLive = 1 THEN apositiontaking ELSE 0 END)     
	  ,@v161alivepositiontaking_86 = MAX(CASE WHEN bettype = 86 AND sporttype = 161 AND isLive = 1 THEN apositiontaking ELSE 0 END)     
	  ,@v161alivepositiontaking_87 = MAX(CASE WHEN bettype = 87 AND sporttype = 161 AND isLive = 1 THEN apositiontaking ELSE 0 END)     
	  ,@v161alivepositiontaking_89 = MAX(CASE WHEN bettype = 89 AND sporttype = 161 AND isLive = 1 THEN apositiontaking ELSE 0 END)     
	  ,@v161alivepositiontaking_90 = MAX(CASE WHEN bettype = 90 AND sporttype = 161 AND isLive = 1 THEN apositiontaking ELSE 0 END)     
	      
	  ,@v161mlivepositiontaking_85 = MAX(CASE WHEN bettype = 85 AND sporttype = 161 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	  ,@v161mlivepositiontaking_86 = MAX(CASE WHEN bettype = 86 AND sporttype = 161 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	  ,@v161mlivepositiontaking_87 = MAX(CASE WHEN bettype = 87 AND sporttype = 161 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	  ,@v161mlivepositiontaking_89 = MAX(CASE WHEN bettype = 89 AND sporttype = 161 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	  ,@v161mlivepositiontaking_90 = MAX(CASE WHEN bettype = 90 AND sporttype = 161 AND isLive = 1 THEN mpositiontaking ELSE 0 END)    
	      
	FROM Dep_Custsetting3rd WITH(NOLOCK)    
	WHERE custid = @recommend and bettype IN (81,83,85,86,87,88,89,90) and sporttype = 161
	    
	--- Keno    
	SELECT  @v202apositiontaking_1501 = MAX(CASE WHEN bettype = 1501 AND sporttype = 202 THEN apositiontaking ELSE 0 END)     
	  ,@v202mpositiontaking_1501 = MAX(CASE WHEN bettype = 1501 AND sporttype = 202 THEN mpositiontaking ELSE 0 END)     
	FROM custsettinggame with(nolock)     
	WHERE custid = @recommend and bettype = 1501 and sporttype =202
	    
	      
	----INSERT MEMBER ---------------------------------------------------------------    
	    
	     
	declare @ErrType varchar(4000)     
	    
	Select @ErrCode = 0    
	    
	--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   
	   
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------    
	    
	    
	    
	SELECT @MaxCredit_Mem = isnull(maxcredit,0) FROM CustAgent WITH (NOLOCK)     
	WHERE CustID = @recommend    
	    
	select @spositiontaking_1 = 0, @slivepositiontaking_1 = 0    
	select @spositiontaking_3 = 0, @slivepositiontaking_3 = 0      
	select @spositiontaking_7 = 0, @slivepositiontaking_7 = 0      
	select @spositiontaking_8 = 0, @slivepositiontaking_8 = 0     
	select @spositiontaking_2 = 0     
	select @spositiontaking_4 = 0     
	    
	select @spositiontaking_5 = 0     
	select @spositiontaking_6 = 0     
	select @spositiontaking_9 = 0     
	select @spositiontaking_10 = 0    
	    
	select @v2spositiontaking_1 = 0     
	select @v2spositiontaking_2 = 0     
	select @v2spositiontaking_3 = 0     
	select @v2spositiontaking_7 = 0     
	select @v2spositiontaking_8 = 0     
	--select @v2spositiontaking_9 = 0     
	select @v2spositiontaking_20 = 0     
	    
	select @v3spositiontaking_1 = 0     
	select @v3spositiontaking_2 = 0     
	select @v3spositiontaking_3 = 0     
	select @v3spositiontaking_20 = 0    
	    
	select @v5spositiontaking_1 = 0    
	select @v5spositiontaking_2 = 0     
	select @v5spositiontaking_3 = 0     
	select @v5spositiontaking_20 = 0     
	    
	select @v8spositiontaking_1 = 0     
	select @v8spositiontaking_3 = 0     
	select @v8spositiontaking_20 = 0     
	    
	select @v10spositiontaking_1 = 0     
	select @v10spositiontaking_2 = 0    
	select @v10spositiontaking_3 = 0     
	select @v10spositiontaking_20 = 0    
	    
	select @v11spositiontaking_1 = 0    
	select @v11spositiontaking_20 = 0    

	select @v44spositiontaking_3 = 0    
	    

	select @v99spositiontaking_1 = 0    
	select @v99spositiontaking_2 = 0    
	select @v99spositiontaking_3 = 0    
	select @v99spositiontaking_9 = 0    
	select @v99spositiontaking_20 = 0    
	
	select @v161spositiontaking_81 = 0    
	select @v161spositiontaking_83 = 0    
	select @v161spositiontaking_88 = 0    
	select @v161slivepositiontaking_85 = 0    
	select @v161spositiontaking_86 = 0, @v161slivepositiontaking_86 = 0    
	select @v161slivepositiontaking_87 = 0     
	select @v161slivepositiontaking_89 = 0     
	select @v161slivepositiontaking_90 = 0     
	    
	
	select @v202spositiontaking_1501 = 0    
	    
	SELECT  @adiscount  = MAX(CASE WHEN bettype = 1 THEN adiscount ELSE 0 END)    
	  ,@adiscountcs = MAX(CASE WHEN bettype = 4 THEN adiscount ELSE 0 END)    
	  ,@adiscount1x2 = MAX(CASE WHEN bettype = 5 THEN adiscount ELSE 0 END)    	 
	FROM Dep_CustSetting WITH(NOLOCK)    
	WHERE custid = @mrecommend AND sporttype =1 AND bettype IN (1,4,5) AND isLive = 0    
	    
	    
	    
	SELECT     
	   @v161adiscount    = MAX(CASE WHEN sporttype = 161 AND bettype = 81 THEN adiscount ELSE 0 END)    
	FROM Dep_CustSetting3rd WITH(NOLOCK)    
	WHERE custid = @mrecommend AND islive=0    
	 AND bettype =81 AND sporttype =161   

	--- Keno    
	select @v202adiscount_1501 = MAX(CASE WHEN sporttype = 202 AND bettype = 1501 THEN adiscount ELSE 0 END)     
	from custsettinggame with (nolock)     
	where custid = @mrecommend and bettype = 1501 and sporttype = 202
	    
	SELECT  @sdiscount  = MAX(CASE WHEN bettype = 1 THEN sdiscount ELSE 0 END)    
	  ,@sdiscountcs = MAX(CASE WHEN bettype = 4 THEN sdiscount ELSE 0 END)    
	  ,@sdiscount1x2 = MAX(CASE WHEN bettype = 5 THEN sdiscount ELSE 0 END)   	  
	FROM Dep_CustSetting WITH(NOLOCK)    
	WHERE custid = @srecommend AND sporttype =1 AND bettype IN (1,4,5) AND isLive = 0    
	    
	SELECT     
		@v161sdiscount    = MAX(CASE WHEN sporttype = 161 AND bettype = 81 THEN sdiscount ELSE 0 END)    
	FROM Dep_CustSetting3rd WITH(NOLOCK)    
	WHERE custid = @srecommend AND islive=0    
	 AND bettype =81 AND sporttype =161

	--- Keno    
	select  @v202sdiscount_1501 = MAX(CASE WHEN sporttype = 202 AND bettype = 1501 THEN sdiscount ELSE 0 END)      
	from custsettinggame with (nolock)     
	where custid = @srecommend and bettype = 1501 and sporttype =202   
	    
	    
	select    
	 @playerdiscount = case when @playerdiscount > @adiscount then @adiscount else @playerdiscount end,    
	 @playerdiscountcs = case when @playerdiscountcs > @adiscountcs then @adiscountcs else @playerdiscountcs end,    
	 --1x2    
	 @playerdiscount1x2 = case when @playerdiscount1x2 > @adiscount1x2 then @adiscount1x2 else @playerdiscount1x2 end,    
	
	 --v161    
	 @v161playerdiscount= case when @v161playerdiscount> @v161discount then @v161discount else @v161playerdiscount end,    
	 
	 ---  Keno    
	 @v202playerdiscount_1501 = case when @v202playerdiscount_1501 > @v202discount_1501 then @v202discount_1501 else @v202playerdiscount_1501 end    
	    
	     
	-- NOTE : agent can set discount to member more than what he get.   but should not more than Master discount    
	-- which normally Master is get FULL discount from company  (Later might need to detect at SUPERAGENT level    
	    
	SET ANSI_WARNINGS OFF    
	    
	SELECT  @MinMinBet  = ISNULL(MAX(CASE WHEN sporttype = 1 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBet  = ISNULL(MIN(CASE WHEN sporttype = 1 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv2 = ISNULL(MAX(CASE WHEN sporttype = 2 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv2 = ISNULL(MIN(CASE WHEN sporttype = 2 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv3 = ISNULL(MAX(CASE WHEN sporttype = 3 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv3 = ISNULL(MIN(CASE WHEN sporttype = 3 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv5 = ISNULL(MAX(CASE WHEN sporttype = 5 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv5 = ISNULL(MIN(CASE WHEN sporttype = 5 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv8 = ISNULL(MAX(CASE WHEN sporttype = 8 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv8 = ISNULL(MIN(CASE WHEN sporttype = 8 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv10 = ISNULL(MAX(CASE WHEN sporttype = 10 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv10 = ISNULL(MIN(CASE WHEN sporttype = 10 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv11 = ISNULL(MAX(CASE WHEN sporttype = 11 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv11 = ISNULL(MIN(CASE WHEN sporttype = 11 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv44 = ISNULL(MAX(CASE WHEN sporttype = 44 AND bettype = 3 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv44 = ISNULL(MIN(CASE WHEN sporttype = 44 AND bettype = 3 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv99 = ISNULL(MAX(CASE WHEN sporttype = 99 AND bettype = 1 AND minbet <> 0 THEN minbet ELSE NULL END),0)    ,@MaxMaxBetv99 = ISNULL(MIN(CASE WHEN sporttype = 99 AND bettype = 1 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	  ,@MinMinBetv99MP= ISNULL(MAX(CASE WHEN sporttype = 99 AND bettype = 9 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv99MP= ISNULL(MIN(CASE WHEN sporttype = 99 AND bettype = 9 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    
	   
	FROM Dep_Custsetting cs WITH(NOLOCK)    
	 INNER JOIN custinfo ci WITH(NOLOCK) ON (cs.custid = ci.custid or cs.custid = ci.mrecommend or cs.custid = ci.srecommend)    
	WHERE ci.custid = @recommend AND cs.bettype IN (1,3,9) AND cs.sporttype IN (1,2,3,5,8,10,11,44,99) and cs.islive = 0    
	    
	    
	    
	SELECT  @MinMinBetv161  = ISNULL(MAX(CASE WHEN sporttype = 161 AND bettype = 81 AND minbet <> 0 THEN minbet ELSE NULL END),0)    
	  ,@MaxMaxBetv161  = ISNULL(MIN(CASE WHEN sporttype = 161 AND bettype = 81 AND maxbet <> 0 THEN maxbet ELSE NULL END),0)    	    
	FROM Dep_CustSetting3rd cs WITH (NOLOCK)    
	 INNER JOIN custinfo ci WITH (NOLOCK) on (cs.CustID = ci.CustID or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)     
	WHERE ci.custid = @recommend AND cs.bettype =81 and cs.sporttype =161   
	    
	Select     
	 @MaxMaxperMatch = IsNull(Min(case when cs.MaxPerMatch = 0 then NULL else cs.MaxPerMatch end),0),     
	 @MaxMaxPerMatchv2 = IsNull(Min(case when cs.MaxPerMatch2 = 0 then NULL else cs.MaxPerMatch2 end),0),    
	 @MaxMaxPerMatchv3 = IsNull(Min(case when cs.MaxPerMatch3 = 0 then NULL else cs.MaxPerMatch3 end),0),    
	 @MaxMaxPerMatchv5 = IsNull(Min(case when cs.MaxPerMatch5 = 0 then NULL else cs.MaxPerMatch5 end),0),    
	 @MaxMaxPerMatchv8 = IsNull(Min(case when cs.MaxPerMatch8 = 0 then NULL else cs.MaxPerMatch8 end),0),    
	 @MaxMaxPerMatchv10 = IsNull(Min(case when cs.MaxPerMatch10 = 0 then NULL else cs.MaxPerMatch10 end),0),    
	 @MaxMaxPerMatchv11 = IsNull(Min(case when cs.MaxPerMatch11 = 0 then NULL else cs.MaxPerMatch11 end),0), 
	 @MaxMaxPerMatchv44 = IsNull(Min(case when cs.MaxPerMatch44 = 0 then NULL else cs.MaxPerMatch44 end),0), 
	 
	 @MaxMaxPerMatchv99 = IsNull(Min(case when cs.MaxPerMatch99 = 0 then NULL else cs.MaxPerMatch99 end),0),    
	 -- parlay mixed sports    
	 @MaxMaxPerMatchv99MP = isnull(Min(case when cs.MaxPerMatch99MP = 0 then NULL else cs.MaxPerMatch99MP end),0),    
	 --Number game    
	 @MaxMaxPerMatchv161 = isnull(Min(case when cs.MaxPerMatch161 = 0 then NULL else cs.MaxPerMatch161 end),0),    
	 @MaxMaxPerBallv161  = ISNULL(MIN(CASE WHEN cs.MaxPerBall161 = 0 THEN NULL ELSE cs.MaxPerBall161 END), 0)
	    
	from custinfo as cs WITH (NOLOCK)     
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.CustID or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)    
	where ci.custid = @Recommend    
	SET ANSI_WARNINGS ON    
	    
	select @ErrType = ''    
	select @ErrType = @ErrType + sportname + ', '    
	from @tmp_Sports sports inner join    
	(    
		select 1 as sporttype, @MinBet as MinBet, @MinMinBet as MinMinBet    
	 union all select 2 as sporttype, @MinBetv2 as MinBet, @MinMinBetv2 as MinMinBet    
	 union all select 3 as sporttype, @MinBetv3 as MinBet, @MinMinBetv3 as MinMinBet    
	 union all select 5 as sporttype, @MinBetv5 as MinBet, @MinMinBetv5 as MinMinBet    
	 union all select 8 as sporttype, @MinBetv8 as MinBet, @MinMinBetv8 as MinMinBet    
	 union all select 10 as sporttype, @MinBetv10 as MinBet, @MinMinBetv10 as MinMinBet    
	 union all select 11 as sporttype, @MinBetv11 as MinBet, @MinMinBetv11 as MinMinBet     
	 union all select 44 as sporttype, @MinBetv44 as MinBet, @MinMinBetv44 as MinMinBet 
	 
	 union all select 99 as sporttype, @MinBetv99 as MinBet, @MinMinBetv99 as MinMinBet    
	 --Parlay mixed     
	 union all  select 99 as sporttype, @MinBetv99MP as MinBet, @MinMinBetv99MP as MinMinBet    
	     
	 --number game    
	 union all select 161 as sporttype, @MinBetv161 as MinBet, @MinMinBetv161 as MinMinBet    
	        
	) as b on sports.sporttype = b.sporttype    
	where MinMinBet>0 and MinBet>0 and MinBet<MinMinBet    
	
	IF @ErrType <>''    
	BEGIN    
		SELECT    
		  @ErrMsg = 'Sorry, min bet must be equal to or greater than Super/Master/Agent min bet ('+@ErrType+').',    
		  @ErrCode = 205    
		
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg

		RETURN    
	END    
	    
	select @ErrType = ''    
	select @ErrType = @ErrType + sportname + ', '    
	from @tmp_Sports sports inner join    
	(    
		select 1 as sporttype, @MaxBet as MaxBet, @MaxMaxBet as MaxMaxBet    
	 union all select 2 as sporttype, @MaxBetv2 as MaxBet, @MaxMaxBetv2 as MaxMaxBet    
	 union all select 3 as sporttype, @MaxBetv3 as MaxBet, @MaxMaxBetv3 as MaxMaxBet    
	 union all select 5 as sporttype, @MaxBetv5 as MaxBet, @MaxMaxBetv5 as MaxMaxBet    
	 union all select 8 as sporttype, @MaxBetv8 as MaxBet, @MaxMaxBetv8 as MaxMaxBet    
	 union all select 10 as sporttype, @MaxBetv10 as MaxBet, @MaxMaxBetv10 as MaxMaxBet    
	 union all select 11 as sporttype, @MaxBetv11 as MaxBet, @MaxMaxBetv11 as MaxMaxBet     
	 union all select 44 as sporttype, @MaxBetv44 as MaxBet, @MaxMaxBetv44 as MaxMaxBet 
	 
	 union all select 99 as sporttype, @MaxBetv99 as MaxBet, @MaxMaxBetv99 as MaxMaxBet      
	     
	 --parlay mixed sports    
	 union all select 99 as sporttype, @MaxBetv99MP as MaxBet, @MaxMaxBetv99MP as MaxMaxBet    
	     
	 --number game     
	 union all select 161 as sporttype, @MaxBetv161 as MaxBet, @MaxMaxBetv161 as MaxMaxBet    
	) as b on sports.sporttype = b.sporttype    
	where MaxMaxBet>0 and MaxBet>0 and MaxBet>MaxMaxBet    
	
	IF @ErrType <>''    
	BEGIN    
		SELECT    
		@ErrMsg = 'Sorry, max bet must be equal to or less than Master/Agent max bet ('+@ErrType+').',    
		@ErrCode = 107  
		
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg  
	 
		RETURN    
	END    
	    
	select @ErrType = ''    
	select @ErrType = @ErrType + sportname + ', '    
	from @tmp_Sports sports inner join    
	(    
		select 1 as sporttype, @MaxPerMatch as MaxPerMatch, @MaxMaxPerMatch as MaxMaxPerMatch    
	 union all select 2 as sporttype, @MaxPerMatchv2 as MaxPerMatch, @MaxMaxPerMatchv2 as MaxMaxPerMatch    
	 union all select 3 as sporttype, @MaxPerMatchv3 as MaxPerMatch, @MaxMaxPerMatchv3 as MaxMaxPerMatch    
	 union all select 5 as sporttype, @MaxPerMatchv5 as MaxPerMatch, @MaxMaxPerMatchv5 as MaxMaxPerMatch    
	 union all select 8 as sporttype, @MaxPerMatchv8 as MaxPerMatch, @MaxMaxPerMatchv8 as MaxMaxPerMatch    
	 union all select 10 as sporttype, @MaxPerMatchv10 as MaxPerMatch, @MaxMaxPerMatchv10 as MaxMaxPerMatch    
	 union all select 11 as sporttype, @MaxPerMatchv11 as MaxPerMatch, @MaxMaxPerMatchv11 as MaxMaxPerMatch    
	 union all select 44 as sporttype, @MaxPerMatchv44 as MaxPerMatch, @MaxMaxPerMatchv44 as MaxMaxPerMatch  
	
	 union all select 99 as sporttype, @MaxPerMatchv99 as MaxPerMatch, @MaxMaxPerMatchv99 as MaxMaxPerMatch    
	 --mixed sports    
	 union all select 99 as sporttype, @MaxPerMatchv99MP as MaxPerMatch, @MaxMaxPerMatchv99MP as MaxMaxPerMatch    
	 --number game    
	 union all select 161 as sporttype, @MaxPerMatchv161 as MaxPerMatch, @MaxMaxPerMatchv161 as MaxMaxPerMatch       
	) as b on sports.sporttype = b.sporttype    
	where MaxMaxPerMatch>0 and MaxPerMatch>0 and MaxPerMatch>MaxMaxPerMatch    
	
	IF @ErrType <>''    
	BEGIN    
		SELECT    
		@ErrMsg = 'Sorry, Max Per Match must be equal to or less than Master/Agent Max Per Match ('+@ErrType+').',    
		@ErrCode = 107    

		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg

		RETURN    
	END    
	    
	SELECT @ErrType = ''    
	IF @MaxPerBallv161 > 0 AND @MaxMaxPerBallv161 > 0 AND @MaxPerBallv161 > @MaxMaxPerBallv161    
	BEGIN    
		SELECT @ErrType = @ErrType + sportname     
		FROM @tmp_Sports    
		WHERE sporttype = 161    
	     
		SELECT @ErrMsg= 'Sorry, Max Per ball must be equal to or less than Master/Agent Max Per Match ('+@ErrType+').',    
			@ErrCode = 107 
			
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg
				   
		RETURN    
	END    
	  
	EXEC dbo.Acc_Dep_CustSetting_Check    
	 @custid	= @custid,    
	 @AgentID	= @AgentID,    
	 @Site		= @Site,    
	 @Currency	= @Currency,    
	 @ProductID = NULL,    
	 @SuperID	= @srecommend,    
	 @ErrCode	= @ErrCode OUTPUT,    	   
	 @ErrMsg	= @ErrMsg OUTPUT

	IF @ErrCode<>0
	BEGIN
		SELECT @ErrMsg = 'Check Customer''s Bet Limits: ' + @ErrMsg
		
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg
		RETURN
	END

	/*  --20181011@Kean
		--Comment for  reactivation deposit member
		--Get from archived database
	    
	select @pwdexpiry = dateadd(dd, 30, getdate())    
	*/
	    
	IF @Aclosed = 1    
	BEGIN    
		SELECT     
		@ErrMsg = 'Agent was closed. Cannot reactivate its member.',     
		@ErrCode=211    

		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg

		RETURN    
	END    
	    
	--check suspended of Agent     
	if @Asuspended =1 and @suspendedFlag is null    
	BEGIN    
	 set @suspended =1    
	END    
	    
	-----------------------------------------------    
	--generate the username automatically    
	/* --- old version    
	Select @username = isnull(max(cast(replace(username, @AgUsername, '') as int)),0)    
	from customer with (nolock)    
	where recommend = @recommend and roleid = 1    
	 and charindex(@AgUsername, username) = 1    
	*/    
	/* old version    
	select @username = isnull(cast(replace(username,@AgUsername,'') as int),0)    
	from customer witH(nolock)    
	where custid = ( select max(custid)     
	    
		 from dbo.customer with(nolocK)     
		 where recommend = @recommend     
		  and roleid = 1           
		)    
	        
	    
	if isnumeric(@username) = 1    
	BEGIN    
	 select @username = convert(varchar(20), convert(int, @username) + 1)    
	 if len(@username)<3    
	 BEGIN    
	  select @Username = right('00' + @username, 3)    
	 END    
	END    
	else    
	BEGIN    
	 select @UserName = '001'    
	END    
	    
	select @username = @agusername  + @username    
	select @username = replace(@username, ' ', '')    
	*/

	/*  --20181011@Kean
		--Comment for reactivation deposit member
		--Get from archived database
	     
	--20140812: Change rule generate username    
	IF (@UserName NOT LIKE '%BetTrade%' AND  @UserName NOT LIKE '%CashOut%') OR @UserName IS NULL  
	BEGIN  
	SELECT @UserName = dbo.f_LAS_GenerateUsername(@recommend)    
	IF @UserName = ''    
	BEGIN    
	 SELECT @ErrMsg = 'The username is not available.'    
	  ,@ErrCode = 11    
	    
	 RETURN    
	END    
	END  
	--20080623: Add sitename prefix to the DepositUsername    
	select @DepositUserName = @site + '$' + @DepositUserName    
	 */ 
	    
	--Check the unique username    
	if exists (select 1 from customer c with (NOLOCK)        
	   where @CheckUniqueUsername2=1  AND c.username2 = @username2
		)    
	 or exists (select 1 from customer with(NOLOCK) where username = @UserName)    
	 or exists (select 1 from custsub with(NOLOCK) where username = @UserName)    
	BEGIN    
		SELECT @ErrMsg = 'The username is not available.', @ErrCode = 11
		
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'The username is already existing in customer'
				    
		RETURN    

	END    
	-----------------------------------------------    
	--reset the @site param    
	select @site=case when @ugroup like 'indo_' then 'INDO' else '' end,    
	 @ugroup = case when @ugroup like 'indo_' then right(@ugroup,1) else @ugroup end    
	
	IF EXISTS(SELECT 1 FROM customer (NOLOCK) WHERE custid = @CustID)
	BEGIN
		SELECT @ErrMsg = 'This member has been reactivated by someone else.'
		SELECT @ErrCode = 22

		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg
	END   

	--Insert general data     
	EXEC dbo.Dot_Dep_Customer_Archive_InsertCustomerInfo    
	 @custid = @custid,    
	 @firstname = @firstname,    
	 @lastname = @lastname,    
	 @creator = @recommend,    
	 @username = @username,    
	 @userpwd = @Password,    
	 @pwdexpiry = @pwdexpiry,    
	 @currency = @currency,    
	 @site = @site,    
	 @ugroup = @ugroup,
	 @createDate = @createDate, --20181011@Kean: Support for reactivation of member
	 @birthday = @birthday,
	 @refcode1 = @refcode1,
	 @remark = @remark,
	 @refcode2 = @refcode2,
	 @username2 = @username2,    
	 @srecommend = @srecommend,    
	 @mrecommend = @mrecommend,    
	 @recommend = @recommend,    
	 @roleid = 1,    
	 @phone = @phone,    
	 @mobilephone = @mobilephone,    
	 @email = @Email,    
	 @fax = @fax,    
	 @address = @address,    
	 @city = @city,    
	 @state = @state,    
	 @country = @Country,    
	 @postal = @postal,
	 @TransferOption = null,    
	 @suspended = @suspended,    

	 @matchlimit = @matchlimit,    
	 @virtualmultiplier = @virtualmultiplier,    
	   
	 @DisableNumber = @DisableNumber,    
	 @DoubleCommLosing = 0, ----@DoubleCommLosing, 20130111@Lukas: hardcode    
	 @DisableCasinoBonus = @DisableCasinoBonus,      
	 
	 @MaxPerMatch = @MaxPerMatch,    
	 @MaxPerMatchv2 = @MaxPerMatchv2,    
	 @MaxPerMatchv3 = @MaxPerMatchv3,    
	 @MaxPerMatchv5 = @MaxPerMatchv5,    
	 @MaxPerMatchv8 = @MaxPerMatchv8,    
	 @MaxPerMatchv10 = @MaxPerMatchv10,    
	 @MaxPerMatchv11 = @MaxPerMatchv11,    
	 @MaxPerMatchv44 = @MaxPerMatchv44,
	
	 @MaxPerMatchv99 = @MaxPerMatchv99,    
	 @MaxPerMatchv99MP = @MaxPerMatchv99MP,    

	 @MaxPerMatchv161 = @MaxPerMatchv161,    
	 @MaxPerBallv161 = @MaxPerBallv161,    
	    
	 @HideKeno = @HideKeno,    
	 @credit = 0,    
	 @IP = '',    
	 @TransferOption_dec = null,    
	 @Language = 'E',    
	 @ErrCode = @ErrCode OUTPUT,    
	 @ErrMsg = @ErrMsg OUTPUT    
	
	IF @ErrCode <> 0 
	BEGIN   
		SELECT @ErrMsg = 'Failed to insert customer/custinfo: ' + @ErrMsg
		EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg
		
		RETURN  
	END  
	    
	     
	--print @v2mpositiontaking_20    
	INSERT INTO [dbo].[Dep_CustSetting]([custid], [bettype], [sporttype], [apositiontaking], [mpositiontaking], [spositiontaking], [playerdiscount], [discount], [adiscount], [sdiscount], [MinBet], [MaxBet], [islive])    
	select @custid, 1, 1, @apositiontaking_1, @mpositiontaking_1,@spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount,@MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 1, 1, @alivepositiontaking_1, @mlivepositiontaking_1, @slivepositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount,@MinBet, @MaxBet, 1    
	UNION ALL    
	select @custid, 3, 1, @apositiontaking_3, @mpositiontaking_3, @spositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 3, 1, @alivepositiontaking_3, @mlivepositiontaking_3, @slivepositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBet, @MaxBet, 1    
	UNION ALL    
	select @custid, 7, 1, @apositiontaking_7, @mpositiontaking_7, @spositiontaking_7, @playerdiscount, @discount, @adiscount, @sdiscount,@MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 7, 1, @alivepositiontaking_7, @mlivepositiontaking_7, @slivepositiontaking_7, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBet, @MaxBet, 1    
	UNION ALL    
	select @custid, 8, 1, @apositiontaking_8, @mpositiontaking_8, @spositiontaking_8, @playerdiscount, @discount, @adiscount, @sdiscount,@MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 8, 1, @alivepositiontaking_8, @mlivepositiontaking_8, @slivepositiontaking_8, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBet, @MaxBet, 1    
	UNION ALL    
	select @custid, 2, 1, @apositiontaking_2, @mpositiontaking_2, @spositiontaking_2, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 4, 1, @apositiontaking_4, @mpositiontaking_4, @spositiontaking_4, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs,@MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 5, 1, @apositiontaking_5, @mpositiontaking_5, @spositiontaking_5, @playerdiscount1x2, @discount1x2, @adiscount1x2, @sdiscount1x2, @MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 6, 1, @apositiontaking_6, @mpositiontaking_6, @spositiontaking_6, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 9, 1, @apositiontaking_9, @mpositiontaking_9, @spositiontaking_9, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBet, @MaxBet, 0    
	UNION ALL    
	select @custid, 10, 1, @apositiontaking_10, @mpositiontaking_10, @spositiontaking_10,@playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs,@MinBet, @MaxBet, 0    
	    
	UNION ALL    
	select @custid, 1, 2, @v2apositiontaking_1, @v2mpositiontaking_1, @v2spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv2, @MaxBetv2, 0    
	UNION ALL    
	select @custid, 2, 2, @v2apositiontaking_2, @v2mpositiontaking_2, @v2spositiontaking_2, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv2, @MaxBetv2, 0    
	UNION ALL    
	select @custid, 3, 2, @v2apositiontaking_3, @v2mpositiontaking_3, @v2spositiontaking_3,  @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv2, @MaxBetv2, 0    
	UNION ALL    
	select @custid, 7, 2, @v2apositiontaking_7, @v2mpositiontaking_7, @v2spositiontaking_7, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv2, @MaxBetv2, 0    
	UNION ALL    
	select @custid, 8, 2, @v2apositiontaking_8, @v2mpositiontaking_8, @v2spositiontaking_8, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv2, @MaxBetv2, 0    
	UNION ALL    
	select @custid, 20, 2, @v2apositiontaking_20, @v2mpositiontaking_20, @v2spositiontaking_20, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBetv2, @MaxBetv2, 0    
	    
	UNION ALL    
	select @custid, 1, 3, @v3apositiontaking_1, @v3mpositiontaking_1, @v3spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv3, @MaxBetv3, 0    
	UNION ALL    
	select @custid, 2, 3, @v3apositiontaking_2, @v3mpositiontaking_2, @v3spositiontaking_2, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv3, @MaxBetv3, 0    
	UNION ALL    
	select @custid, 3, 3, @v3apositiontaking_3, @v3mpositiontaking_3, @v3spositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv3, @MaxBetv3, 0    
	UNION ALL    
	select @custid, 20, 3, @v3apositiontaking_20, @v3mpositiontaking_20, @v3spositiontaking_20, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBetv3, @MaxBetv3, 0    
	    
	UNION ALL    
	select @custid, 1, 5, @v5apositiontaking_1, @v5mpositiontaking_1, @v5spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv5, @MaxBetv5, 0    
	UNION ALL    
	select @custid, 2, 5, @v5apositiontaking_2, @v5mpositiontaking_2, @v5spositiontaking_2,@playerdiscount, @discount, @adiscount, @sdiscount,@MinBetv5, @MaxBetv5, 0    
	UNION ALL    
	select @custid, 3, 5, @v5apositiontaking_3, @v5mpositiontaking_3, @v5spositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv5, @MaxBetv5, 0    
	UNION ALL    
	select @custid, 20, 5, @v5apositiontaking_20, @v5mpositiontaking_20, @v5spositiontaking_20, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBetv5, @MaxBetv5, 0    
	    
	UNION ALL    
	select @custid, 1, 8, @v8apositiontaking_1, @v8mpositiontaking_1, @v8spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount,@MinBetv8, @MaxBetv8, 0    
	UNION ALL    
	select @custid, 3, 8, @v8apositiontaking_3, @v8mpositiontaking_3, @v8spositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv8, @MaxBetv8, 0    
	UNION ALL    
	select @custid, 20, 8, @v8apositiontaking_20, @v8mpositiontaking_20, @v8spositiontaking_20, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBetv8, @MaxBetv8, 0    
	    
	UNION ALL    
	select @custid, 1, 10, @v10apositiontaking_1, @v10mpositiontaking_1, @v10spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv10, @MaxBetv10, 0    
	UNION ALL    
	select @custid, 2, 10, @v10apositiontaking_2, @v10mpositiontaking_2, @v10spositiontaking_2, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv10, @MaxBetv10, 0    
	UNION ALL    
	select @custid, 3, 10, @v10apositiontaking_3, @v10mpositiontaking_3, @v10spositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv10, @MaxBetv10, 0    
	UNION ALL    
	select @custid, 20, 10, @v10apositiontaking_20, @v10mpositiontaking_20, @v10spositiontaking_20, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBetv10, @MaxBetv10, 0    
	    
	UNION ALL    
	select @custid, 1, 11, @v11apositiontaking_1, @v11mpositiontaking_1, @v11spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv11, @MaxBetv11, 0    
	UNION ALL    
	select @custid, 20, 11, @v11apositiontaking_20, @v11mpositiontaking_20, @v11spositiontaking_20, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBetv11, @MaxBetv11, 0    
	 
	UNION ALL    
	select @custid, 3, 44, @v44apositiontaking_3, @v44mpositiontaking_3, @v44spositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv44, @MaxBetv44, 0  
	    
	UNION ALL    
	select @custid, 1, 99, @v99apositiontaking_1, @v99mpositiontaking_1, @v99spositiontaking_1, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv99, @MaxBetv99, 0    
	UNION ALL    
	select @custid, 2, 99, @v99apositiontaking_2, @v99mpositiontaking_2, @v99spositiontaking_2, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv99, @MaxBetv99, 0    
	UNION ALL    
	select @custid, 3, 99, @v99apositiontaking_3, @v99mpositiontaking_3, @v99spositiontaking_3, @playerdiscount, @discount, @adiscount, @sdiscount, @MinBetv99, @MaxBetv99, 0    
	UNION ALL     
	select @custid, 9, 99, @v99apositiontaking_9, @v99mpositiontaking_9, @v99spositiontaking_9, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs, @MinBetv99MP, @MaxBetv99MP, 0    
	UNION ALL    
	select @custid, 20, 99, @v99apositiontaking_20, @v99mpositiontaking_20, @v99spositiontaking_20, @playerdiscountcs, @discountcs, @adiscountcs, @sdiscountcs,  @MinBetv99, @MaxBetv99, 0    
	 
	--Insert into custsetting3rd    
	    
	INSERT INTO [Dep_CustSetting3rd]    
			   ([custid]    
			   ,[bettype]    
			   ,[sporttype]    
			   ,[apositiontaking]    
			   ,[mpositiontaking]    
			   ,[spositiontaking]    
			   ,[playerdiscount]    
			   ,[discount]    
			   ,[adiscount]    
			   ,[sdiscount]    
			   ,[minbet]    
			   ,[maxbet]    
			   ,[islive])    
	
	--v161    
   
	select @custid, 81, 161, @v161apositiontaking_81, @v161mpositiontaking_81, @v161spositiontaking_81, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 0     
	UNION ALL              
	select @custid, 83, 161, @v161apositiontaking_83, @v161mpositiontaking_83, @v161spositiontaking_83, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 0    
	UNION ALL              
	select @custid, 88, 161, @v161apositiontaking_88, @v161mpositiontaking_88, @v161spositiontaking_88, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 0    
	UNION ALL    
	select @custid, 85, 161, @v161alivepositiontaking_85, @v161mlivepositiontaking_85, @v161slivepositiontaking_85, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 1    
	UNION ALL    
	select @custid, 86, 161, @v161apositiontaking_86, @v161mpositiontaking_86, @v161spositiontaking_86, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 0    
	UNION ALL    
	select @custid, 86, 161, @v161alivepositiontaking_86, @v161mlivepositiontaking_86, @v161slivepositiontaking_86, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 1    
	UNION ALL    
	select @custid, 87 , 161, @v161alivepositiontaking_87, @v161mlivepositiontaking_87, @v161slivepositiontaking_87, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 1    
	UNION ALL    
	select @custid, 89 , 161, @v161alivepositiontaking_89, @v161mlivepositiontaking_89, @v161slivepositiontaking_89, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 1    
	UNION ALL    
	select @custid, 90 , 161, @v161alivepositiontaking_90, @v161mlivepositiontaking_90, @v161slivepositiontaking_90, @v161playerdiscount, @v161discount, @v161adiscount, @v161sdiscount, @MinBetv161, @MaxBetv161, 1    
	    
	if (not exists (select 1 from Dep_CustSetting with (NOLOCK) where custid = @custid) or not exists (select 1 from Dep_CustSetting3rd with (NOLOCK) where custid = @custid)) or @@Error <> 0    
	BEGIN    
	 --Error occurs    
	 SELECT     
	  @ErrMsg = 'Add member fail. Please try again',    
	  @ErrCode=215    
	     
	 -- MANUALLY ROLLBACK    
	 DELETE Dep_CustSetting WHERE CustID = @CustID    
	 DELETE Dep_CustSetting3rd WHERE CustID = @CustID    
	 EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID  
	 
	 EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'Failed to insert Dep_CustSetting/Dep_CustSetting3rd'
				  
	 RETURN    
	END    


	-- Keno    
	INSERT INTO CustSettingGame(custid, bettype, sporttype, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount)    
	SELECT @custid, 1501, 202, @v202apositiontaking_1501, @v202mpositiontaking_1501, @v202spositiontaking_1501, @v202playerdiscount_1501, @v202discount_1501, @v202adiscount_1501, @v202sdiscount_1501    
	IF @@ERROR <> 0    
	BEGIN    
	 --Error occurs    
	 SELECT     
	  @ErrMsg = 'Add member fail. Please try again',    
	  @ErrCode=218    
	    
	 -- MANUALLY ROLLBACK    
	 DELETE Dep_CustSetting WHERE CustID = @CustID    
	 DELETE Dep_CustSetting3rd WHERE CustID = @CustID    
	
	 DELETE CustSettingGame WHERE CustID = @CustID    
	 EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID   
	 
	 EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'Failed to insert CustSettingGame'
				 
	 RETURN    
	END    
	    
	-- Keno    
	INSERT INTO CustGameType (GameTypeID, CustID, MaxPerGameType, MinBet, MaxBet, IsDisabled)    
	SELECT cg.GameTypeID, @CustID, isnull(t.maxpergametype,cg.MaxPerGameType), cg.MinBet, isnull(t.maxbet,cg.MaxBet), cg.IsDisabled    
	FROM CustGameType cg WITH (NOLOCK)    
	 INNER JOIN @tmp_GameType gt ON cg.GameTypeID = gt.GameTypeID    
	 LEFT JOIN @custgametype t ON cg.GameTypeID = t.gametypeid    
	WHERE cg.CustID = @recommend AND gt.IBCBetTypeID BETWEEN 1501 AND 1599    
	IF @@ERROR <> 0    
	BEGIN    
	 --Error occurs    
	 SELECT     
	  @ErrMsg = 'Add member fail. Please try again',    
	  @ErrCode=218    
	    
	 -- MANUALLY ROLLBACK    
	 DELETE Dep_CustSetting WHERE CustID = @CustID    
	 DELETE Dep_CustSetting3rd WHERE CustID = @CustID    
	
	 DELETE CustSettingGame WHERE CustID = @CustID    
	 DELETE CustGameType WHERE CustID = @CustID    
	 EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID    

	 EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'Failed to insert CustGameType'

	 RETURN    
	END    
	    
	---------------------------------------------------------------------------------    
	---- Create balance for new customer    
	--EXEC DBTXN.bodb02.dbo.Dot_BalanceInsCredit @CustID = @CustID  
	EXEC DBTXN.bodb02.dbo.Dot_BalanceCreditInitialize @CustID = @CustID, @errCode = @ErrCode OUTPUT
	 
	    
	IF @ErrCode <> 0    
	BEGIN     
	 --Error occurs    
	 SELECT     
	  @ErrMsg = 'Add member fail. Please try again',    
	  @ErrCode=215    
	     
	 -- MANUALLY ROLLBACK    
	 DELETE Dep_CustSetting WHERE CustID = @CustID    
	 DELETE Dep_CustSetting3rd WHERE CustID = @CustID    

	 DELETE CustSettingGame WHERE CustID = @CustID    
	 DELETE CustGameType WHERE CustID = @CustID    
	 EXEC DBTXN.bodb02.dbo.Dot_BalanceCreditRemove @CustID = @CustID --EXEC DBTXN.bodb02.dbo.Dot_BalanceDelCredit @CustID = @CustID
	 EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID  
	 
	 EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'Failed to insert credit balance tables'
				  
	 RETURN    
	END    
	    
	--EXEC DBTXN.bodb02.dbo.Dot_BalanceInsDebit @CustID = @CustID    
	EXEC DBTXN.bodb02.dbo.Dot_BalanceDebitInitialize @CustID = @CustID, @errCode = @ErrCode OUTPUT    
	    
	IF @ErrCode <> 0    
	BEGIN     
	 --Error occurs    
	 SELECT     
	  @ErrMsg = 'Add member fail. Please try again',    
	  @ErrCode=215    
	     
	 -- MANUALLY ROLLBACK    
	 DELETE Dep_CustSetting WHERE CustID = @CustID    
	 DELETE Dep_CustSetting3rd WHERE CustID = @CustID    
	
	 DELETE CustSettingGame WHERE CustID = @CustID    
	 DELETE CustGameType WHERE CustID = @CustID    
	 EXEC DBTXN.bodb02.dbo.Dot_BalanceCreditRemove @CustID = @CustID --EXEC DBTXN.bodb02.dbo.Dot_BalanceDelCredit @CustID = @CustID
	 EXEC DBTXN.bodb02.dbo.Dot_BalanceDebitRemove @CustID = @CustID --EXEC DBTXN.bodb02.dbo.Dot_BalanceDelDebit @CustID = @CustID    
	 EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID    

	 EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'Failed to insert debit balance tables'

	 RETURN    
	END



	/*HELEN-CUSTOMER SETTING DCS DEPOSIT-START*/
	DECLARE @DCSErrCode INT = 0
	EXEC dbo.Acc_Dep_DynamicCustSetting_00
			@CustID				= @CustID
			, @SuperID			= @srecommend
			, @MasterID			= @mrecommend
			, @AgentID			= @recommend
			, @RoleID			= 1
			, @ProductID		= NULL
			, @ErrCode			= @DCSErrCode OUTPUT
				
	IF @DCSErrCode <> 0 
	BEGIN
		 --Error occur
		 SET @ErrCode = 911
		 -- ROLLBACK MANUALLY
		 -- MANUALLY ROLLBACK    
		 DELETE Dep_CustSetting WHERE CustID = @CustID    
		 DELETE Dep_CustSetting3rd WHERE CustID = @CustID    
	
		 DELETE CustSettingGame WHERE CustID = @CustID    
		 DELETE CustGameType WHERE CustID = @CustID    
		 EXEC DBTXN.bodb02.dbo.Dot_BalanceCreditRemove @CustID = @CustID --EXEC DBTXN.bodb02.dbo.Dot_BalanceDelCredit @CustID = @CustID
		 EXEC DBTXN.bodb02.dbo.Dot_BalanceDebitRemove @CustID = @CustID --EXEC DBTXN.bodb02.dbo.Dot_BalanceDelDebit @CustID = @CustID    
		 EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID   

		 EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= 'Acc_Dep_DynamicCustSetting_00 is failed'
				 
		 RETURN    
	END
	/*HELEN-CUSTOMER SETTING RENOVATION-END*/

	--20181011@Kean: Support for reactivation of deposit member, reinit old balance
	 IF @ReinitOldBalance = 1
	 BEGIN
		SELECT TOP 1 @CustIDBalanceDummy = CustIDBalanceDummy
				   , @ClosingBalance = ClosingBalance
		FROM DBCUST.CustDB.dbo.Dep_Customer_Archived WITH(NOLOCK)
		WHERE Status = 'completed' AND CustID = @CustID

		IF @ClosingBalance <> 0
		BEGIN
			IF @ClosingBalance > 0
			BEGIN
				EXEC DBTXN.bodb02.dbo.Dot_Int_BettransInsTransactionWithoutLog_Cust
						@custid=@CustID,
						@amount= @ClosingBalance,
						@bal_custid=@CustIDBalanceDummy,
						@Bettype = 23203,
						@transdesc = 'Reinit old member balance in deposit reactivation process',
						@ErrCode= @ErrCode OUTPUT,
						@ErrMsg= @ErrMsg OUTPUT
			END
			ELSE
			BEGIN
				EXEC DBTXN.bodb02.dbo.Dot_Int_BettransInsTransactionWithoutLog_Cust
						@custid=@CustID,
						@amount= @ClosingBalance,
						@bal_custid=@CustIDBalanceDummy,
						@Bettype = 23203,
						@transdesc = 'Reinit old member balance in deposit reactivation process',
						@IsCharge = 1, --Not check negative balance
						@ErrCode= @ErrCode OUTPUT,
						@ErrMsg= @ErrMsg OUTPUT
			END

			IF @ErrCode <> 0 
			 BEGIN
				 --Error occur
				 SELECT 
				 @ErrMsg = 'Failed to transfer closing balance: ' + @ErrMsg ,    
				 @ErrCode=215  
				 -- ROLLBACK MANUALLY
				 -- MANUALLY ROLLBACK
				 DELETE FROM Dep_CustPTSetting_Member WHERE CustID = @CustID
				 DELETE FROM Dep_CustSettingMode WHERE CustID = @CustID
				 DELETE FROM Dep_CustStakeLevel_member WHERE CustID = @CustID
				 DELETE FROM Dep_CustBetSetting_Member WHERE CustID = @CustID
				 DELETE FROM Dep_CustProductStatus WHERE CustID = @CustID
		     
				 DELETE Dep_CustSetting WHERE CustID = @CustID    
				 DELETE Dep_CustSetting3rd WHERE CustID = @CustID    
	
				 DELETE CustSettingGame WHERE CustID = @CustID    
				 DELETE CustGameType WHERE CustID = @CustID    
				 EXEC DBTXN.bodb02.dbo.Dot_BalanceCreditRemove @CustID = @CustID --EXEC DBTXN.bodb02.dbo.Dot_BalanceDelCredit @CustID = @CustID
				 EXEC DBTXN.bodb02.dbo.Dot_BalanceDebitRemove @CustID = @CustID --EXEC DBTXN.bodb02.dbo.Dot_BalanceDelDebit @CustID = @CustID    
				 EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID    

				 EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
				, @Action='REACTIVATION'
				, @Status='Failed'
				, @Message= @ErrMsg

				 RETURN    
			 END
		END
	 END
	    
	---------------------------------------------------------------------------------    
	/* --20181011@Kean: Support for reactivation of deposit member	    
	Update customer with (ROWLOCK, UPDLOCK) set      
	 username2 = @DepositUserName,    
	 refcode2 = @DepositUserID    
	where custID = @custID
	*/
	    
	--Bonus
	UPDATE custInfo WITH (ROWLOCK, UPDLOCK) 
	SET BonusWalletFlag=0
	WHERE custID = @custID  
	    
	select @site = site from customer (NOLOCK)    
	WHERE CustID = @AgentID 
	   
	--For Dela, turn member to BA    
	if @site = 'DELA'    
	BEGIN    
	 SET @ErrMsg=''    
	 SET @ErrCode=0    
	     
	 IF (SELECT EnableBA FROM bodb_licensee.dbo.LicenseeBAConfig WITH (NOLOCK) WHERE LicenseeID = 7) = 1    
	 BEGIN    
	    
			EXEC [Lrf_CustomerUpdMemberBAStatus]    
	   @LicenseeID=7,--Dela    
	   @CustID = @CustID,    
	   @ModifyBy = 1, --dbaThien    
	   @IsBA = 1,    
	   @IP = '',    
	   @ErrCode = @ErrCode OUTPUT,    
	   @ErrMsg = @ErrMsg OUTPUT    
	 END    
	END    
	--For Asiabet88, turn USD&EUR players   to BA : 20131230@Jim    
	    
	IF (@site = 'Asiabet88')    
	BEGIN    
	 IF EXISTS (SELECT 1 FROM dbo.Customer WITH (NOLOCK) WHERE CustID=@CustID AND Currency IN (3,6))    
	 BEGIN     
	  SET @ErrMsg=''    
	  SET @ErrCode=0    
	      
	  IF (SELECT EnableBA FROM bodb_licensee.dbo.LicenseeBAConfig WITH (NOLOCK) WHERE LicenseeID = 2) = 1    
	  BEGIN    
			EXEC [Lrf_CustomerUpdMemberBAStatus]    
		@LicenseeID=2,--Asiabet88    
		@CustID = @CustID,    
		@ModifyBy = 3, --pgmviet    
		@IsBA = 1,    
		@IP = '',    
		@ErrCode = @ErrCode OUTPUT,    
		@ErrMsg = @ErrMsg OUTPUT    
	  END    
	 END    
	END
	         
	--20181011@Kean: Support for reactivation of member
	/*   
	IF @AffiliateID is not NULL    
	EXEC DBAFF12BET.Affiliate_12BET.dbo.Aff_CustomerInsMember     
	 @IbcCustID = @CustID,    
	 @AffID = @AffiliateID,    
	 @Username = @DepositUserName,    
	 @IBCUsername = @Username,     
	 @DepositCustID = @DepositUserID,    
	 @FirstName = @FirstName,    
	 @LastName = @LastName,    
	 @Currency = @currency,    
	 @Recommend = @recommend,    
	 @Email = @Email
	 */    
	
	
	    
	--Set default player comm    
	EXEC bodb_Licensee.dbo.Lrf_CustomerSetDefaultComm    
	 @LicenseeName=@site,    
	 @CustID = @CustID,    
	 @ErrCode = @ErrCode OUTPUT,    
	 @ErrMsg = @ErrMsg OUTPUT     
	    
	--Set default bet setting of AG Casino    
	EXEC Lrf_AGC_Customer_SetDefaultSetting      
	 @CustID = @CustID,    
	 @SuperID = @recommend,      
	 @ErrCode = @ErrCode OUTPUT,      
	 @ErrMsg = @ErrMsg OUTPUT    
	    
	--Set default bet setting of 3rd Product    
	EXEC dbo.Lrf_3rdProductCustomerSetDefaultSetting      
	 @CustID = @CustID,    
	 @SuperID = @srecommend,      
	 @ErrCode = @ErrCode OUTPUT,      
	 @ErrMsg = @ErrMsg OUTPUT    
 
	 --Update Dep_Customer_Archived.status = reactivation
	EXEC DBCUST.CustDB.dbo.Acc_CustomerInfo_Execrep_10 @CustID=@CustID, @ActionID=4    

	EXEC DBLOG.bodb_CustomerLog.dbo.Writelog_Dep_Cust_Archive @CustID = @CustID
			, @Action='REACTIVATION'
			, @Status='Done'
			, @Message= 'Finish reactivating customer'

	set @endRun = getdate()    
	set @duration  = datediff (millisecond,@startRun,@endRun)    
	    
	Declare @LogSPData nvarchar(4000)    
	    
	Select @LogSPData = '<Dot_Dep_Customer_Archive_ReactiveCustomer custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +    
	'fname="'+ dbo.f_EncodeXMLValue(coalesce(cast(@firstname as nvarchar(50)),space(1))) + '" ' +    
	'lname="'+ dbo.f_EncodeXMLValue(coalesce(cast(@lastname as nvarchar(50)),space(1))) + '" ' +    
	'creator="'+ coalesce(cast(@CustID as varchar(50)),space(1)) + '" ' +    
	'username="'+ coalesce(cast(@username as varchar(30)),space(1)) + '" ' +    
	'Email="'+ dbo.f_EncodeXMLValue(coalesce(cast(@Email as nvarchar(50)),space(1))) + '" ' +   
	'AgentID="'+ coalesce(cast(@AgentID as varchar(50)),space(1)) + '" ' +   
	'recommend="'+ coalesce(cast(@recommend as varchar(50)),space(1)) + '" ' +    
	'ugroup="'+ coalesce(cast(@ugroup as varchar(5)),space(1)) + '" ' +
	'discount="'+ coalesce(cast(@discount as varchar(50)),space(1)) + '" ' +		 -- Write commission log
	'MinBet="'+ coalesce(cast(@MinBet as varchar(50)),space(1)) + '" ' +			 -- Write betsetting log 
	'MaxBet="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' +    
	'MaxPerMatch="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" ' + 
	'AgentPT="'+ coalesce(cast(@apositiontaking_1 as varchar(50)),space(1)) + '" ' + -- Write PT log
	'suspended="'+ coalesce(cast(@suspended as varchar(50)),space(1)) + '" ' +       -- Write Statuses log
	'DisableNumber="' + coalesce(cast(@DisableNumber as varchar(1)),space(1)) + '" ' +
	'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +    
	'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'    
	BEGIN TRY    
	 EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP    
	  @UserID = @CustID,    
	  @CustID = @CustID,    
	  @ActionID = 1505,    
	  @TrackingValue = @LogSPData,    
	  @duration = @duration    
	END TRY    
	BEGIN CATCH    
	 EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP    
	  @UserID = @CustID,    
	    
	  @CustID = @CustID,    
	  @ActionID = 1505,    
	  @TrackingValue = @LogSPData,    
	  @duration = @duration    
	END CATCH
END
GO 