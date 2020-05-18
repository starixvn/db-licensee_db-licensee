/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Main] 
	@strCustID VARCHAR(MAX)
	,@SBComm DECIMAL(9,8)
	,@NGComm DECIMAL(9,8) = 0
	,@ParlayComm DECIMAL(9,8) = 0
	,@AllbetComm DECIMAL(9,8) = 0
	,@MacauComm DECIMAL(9,8) = 0
	,@PPComm DECIMAL(9,8) = 0
	,@FWComm DECIMAL(9,8) = 0
	,@IsUpdateNG BIT = 0
	,@IsUpdateAllbet BIT = 0
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
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @res AS TABLE (custid INT, isfinished BIT)
	DECLARE @splitter CHAR(1), @string VARCHAR(MAX), @xml XML

	SELECT @splitter = ',', @string = RTRIM(LTRIM(@strCustID))

	SET @xml = CONVERT(XML, @strCustID) 
	
	INSERT INTO @res (custid, isfinished)
	SELECT T.C.value('./@custid', 'INT'), 0
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	DECLARE @ids VARCHAR(MAX), @rowcnt INT, @runningCNT INT, @batchSize int

	SET @runningCNT = 0
	SET @batchSize = 1000

	WHILE (1 = 1)
	BEGIN
		SELECT @ids = '', @runningCNT = @runningCNT + 1

		UPDATE TOP (@batchSize) @res
		SET @ids = @ids + CASE @ids WHEN '' THEN '' ELSE ',' END + cast(custid AS VARCHAR(12))
			,isfinished = 1
		WHERE isfinished = 0

		SELECT @rowcnt = @@rowcount

		EXEC [Acc_ExecRep_Cust_02] 
			@ids = @ids
			,@SBComm = @SBComm
			,@NGComm = @NGComm
			,@ParlayComm = @ParlayComm
			,@AllbetComm = @AllbetComm
			,@MacauComm = @MacauComm
			,@PPComm = @PPComm
			,@FWComm = @FWComm
			,@IsUpdateNG = @IsUpdateNG			
			,@IsUpdateAllbet = @IsUpdateAllbet
			,@IsUpdateMacau = @IsUpdateMacau
			,@IsUpdatePP = @IsUpdatePP
			,@IsUpdateFW = @IsUpdateFW
			
		IF @rowcnt < @batchSize BREAK
		
		-- delay 00.280ms after 20 times continuous running
		IF @runningCNT % 20 = 0 WAITFOR DELAY '00:00:00.100'		
	END
END	
GO


