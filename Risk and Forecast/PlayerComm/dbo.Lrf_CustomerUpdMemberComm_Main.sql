/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Main] 
	@strCustID VARCHAR(MAX)
	,@SBComm DECIMAL(9,8)
	,@NGComm DECIMAL(9,8) = 0
	,@ParlayComm DECIMAL(9,8) = 0
	,@AllbetComm DECIMAL(9,8) = 0
	,@IsUpdateNG BIT = 0
	,@IsUpdateAllbet BIT = 0
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
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @res AS TABLE (custid INT, isfinished BIT)
	DECLARE @splitter CHAR(1), @string VARCHAR(MAX), @xml XML

	SELECT @splitter = ',', @string = RTRIM(LTRIM(@strCustID))
	SET @XML = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

	INSERT INTO @res (custid, isfinished)
	SELECT r.value('.', 'INT'), 0
	FROM @xml.nodes('//root/r') AS RECORDS(r)

	DECLARE @ids VARCHAR(MAX), @rowcnt INT, @runningCNT INT, @batchSize int

	SET @runningCNT = 0
	SET @batchSize = 50

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
			,@IsUpdateNG = @IsUpdateNG
			,@IsUpdateAllbet = @IsUpdateAllbet
		
		
		IF @rowcnt < @batchSize BREAK
		
		-- delay 00.280ms after 20 times continuous running
		IF @runningCNT % 20 = 0 WAITFOR DELAY '00:00:00.280'		
	END
END	
GO


