/*<info serverAlias="DBCUST-CustDB" executers="wsv_lap,wsv_nap,svc_tig" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Main] 
	@strCustID VARCHAR(MAX),
	@DiscountSettings VARCHAR(MAX) = ''		
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
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
		- 20210816@Johnson: Add VGaming [redmine: #159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
		- 220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898]
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230808@Tacy: LAP - Offer Player Commission to VS3 (new) [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240222@Johnson: Restructure Commission [redmine:#179088]
		- 20250804@Tacy: Perf tuning [redmine:#235121]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @res AS TABLE (custid INT, isfinished BIT DEFAULT 0, AgentID INT, IsScannedAgent BIT DEFAULT 0)
	
	INSERT INTO @res (custid)
	SELECT value
	FROM STRING_SPLIT(@strCustID,',')
	WHERE value <> ''

	UPDATE r
	SET r.AgentID = ci.recommend
	FROM dbo.CustInfo ci WITH(NOLOCK)
		INNER JOIN @res r ON ci.custid = r.custid

	DECLARE @ids VARCHAR(MAX), @rowcnt INT, @runningCNT INT, @batchSize INT
	DECLARE @res_batch_tmp AS TABLE (custid INT )
	
	SET @runningCNT = 0
	SET @batchSize = 2000
	
	DECLARE @InputRes_updateComm_batch AS TABLE (custid INT PRIMARY KEY)
	DECLARE @AgentID INT = 0
	
	WHILE (1 = 1) --Scan Agent
	BEGIN
		SELECT TOP 1 @AgentID = t.AgentID
		FROM @res t 
		WHERE IsScannedAgent = 0
			
		IF @@ROWCOUNT = 0 BREAK
			
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
				AND AgentID = @AgentID
			
			IF @@ROWCOUNT = 0 BREAK
	
			SELECT @ids=STUFF((SELECT ',' + CAST(custid AS VARCHAR)
								FROM @res_batch_tmp
								FOR XML PATH('')),1,1,'')

			EXEC [Acc_CustSetting3rd_16] 
				@ids = @ids,
				@AgentID = @AgentID,
				@DiscountSettings = @DiscountSettings
				
			-- delay 00.100ms after 2 times continuous running
			IF @runningCNT % 2 = 0 WAITFOR DELAY '00:00:00.100'
		END

		UPDATE t
		SET t.IsScannedAgent = 1
		FROM @res t
		WHERE AgentID = @AgentID
	END
END	
GO
