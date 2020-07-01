/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Main] 
	@strCustID VARCHAR(MAX)
	,@SBComm DECIMAL(9,8)
	,@NGComm DECIMAL(9,8) = 0
	,@ParlayComm DECIMAL(9,8) = 0
	--,@AllbetComm DECIMAL(9,8) = 0
	,@MacauComm DECIMAL(9,8) = 0
	,@PPComm DECIMAL(9,8) = 0
	,@FWComm DECIMAL(9,8) = 0
	,@IsUpdateSB BIT = 1
	,@IsParlayComm BIT = 1
	,@IsUpdateNG BIT = 0
	--,@IsUpdateAllbet BIT = 0
	,@IsUpdateMacau BIT = 0
	,@IsUpdatePP BIT = 0
	,@IsUpdateFW BIT = 0
AS
/*
	Created: 20120907@Viet
	Task : Update Licensee's players commission in DBCUST
	DB: DBCUST/CustDB
	Original: 

	Revisions:
		- 20131023@Hannah: offer Live Casino commission
		- 20140701@Viet: revise SP
	    - 20150527@Jim: force SB comm of BA member is zero  
	    - 20151005@Jim:HotFix #45031 (revise SP)
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20200409@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @res AS TABLE (custid INT, isfinished BIT)
	
	INSERT INTO @res (custid, isfinished)
	SELECT VAL, 0
	FROM dbo.f_SplitString(@strCustID,',')
	OPTION (MAXRECURSION 0)

	DECLARE @ids VARCHAR(MAX), @rowcnt INT, @runningCNT INT, @batchSize INT
	DECLARE @res_batch_tmp AS TABLE (custid INT )
	
	SET @runningCNT = 0
	SET @batchSize = 750
	
	DECLARE @InputRes_updateComm_batch AS TABLE (custid INT PRIMARY KEY)
	DECLARE @AgentID INT = 0
	DECLARE @MacauComm_Group DECIMAL(9,8)=0,	
			@PPComm_Group DECIMAL(9,8)=0,
			@FWComm_Group DECIMAL(9,8)=0
			--,@AllbetComm_Group DECIMAL(9,8)=0
	
	IF (	--@IsUpdateAllbet = 1 OR 
		@IsUpdateFW = 1 OR @IsUpdateMacau = 1 OR @IsUpdatePP = 1)
	BEGIN		
		SET @AgentID = (SELECT TOP (1) recommend 
							FROM dbo.CustInfo ci WITH(NOLOCK)
								INNER JOIN @res r ON ci.custid = r.custid
							)
		
		SELECT 
			--@AllbetComm_Group = MAX(CASE WHEN BetType = 2401 THEN playerdiscount ELSE 0 END),
			@MacauComm_Group = MAX(CASE WHEN BetType = 4001 THEN playerdiscount ELSE 0 END)
			,@PPComm_Group = MAX(CASE WHEN BetType = 4101 THEN playerdiscount ELSE 0 END)
			,@FWComm_Group = MAX(CASE WHEN BetType = 1011 THEN playerdiscount ELSE 0 END)
		FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
		WHERE AgentID = @AgentID
			AND sporttype IN (212,248,219) -- remove 211
	END	
								
	WHILE (1 = 1)
	BEGIN
		SELECT @ids = '', @runningCNT = @runningCNT + 1
		
		DELETE @res_batch_tmp
		
		UPDATE TOP(@batchSize) t
			SET isfinished = 1
		OUTPUT deleted.custid
		INTO @res_batch_tmp(custid)
		FROM @res t 
		WHERE isfinished = 0
			
		IF @@ROWCOUNT = 0 BREAK
	
		SET @ids = (SELECT custid AS '@custid'
						FROM @res_batch_tmp  t
						FOR XML PATH('r'), ROOT('root')
						)	
		EXEC [Acc_CustSetting3rd_16] 
			@ids = @ids
			,@SBComm = @SBComm
			,@NGComm = @NGComm
			,@ParlayComm = @ParlayComm
			--,@AllbetComm = @AllbetComm
			,@MacauComm = @MacauComm
			,@PPComm = @PPComm
			,@FWComm = @FWComm
			,@IsUpdateSB  = @IsUpdateSB
			,@IsParlayComm  = @IsParlayComm
			,@IsUpdateNG = @IsUpdateNG			
			--,@IsUpdateAllbet = @IsUpdateAllbet
			,@IsUpdateMacau = @IsUpdateMacau
			,@IsUpdatePP = @IsUpdatePP
			,@IsUpdateFW = @IsUpdateFW
			,@AgentID = @AgentID
			--,@AllbetComm_Group = @AllbetComm_Group
			,@MacauComm_Group = @MacauComm_Group	
			,@PPComm_Group = @PPComm_Group
			,@FWComm_Group = @FWComm_Group
			
		-- delay 00.100ms after 5 times continuous running
		IF @runningCNT % 5 = 0 WAITFOR DELAY '00:00:00.280'
	END
	
END	
