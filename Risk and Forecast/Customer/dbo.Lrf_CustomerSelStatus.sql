/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/ 
ALTER  PROCEDURE [dbo].[Lrf_CustomerSelStatus]
	@CustID INT,
	@AdminID INT = 0
AS 
/*
Created: 20101210@Henry
Task : SELECT customer's status
DB: DB052.bodb02
Original: Acc_CustomerSelStatus

Revisions:
   - 20130719@Jim: remove suspended status 
   - 20131023@Jim: Allow users to enable/ disable Casino games for specific players	
   - 20180228@Vicky: Remove LC from product list [Redmine: #85965]
   
Param's Explanation:
• @CustID: customer id.   
*/

SET NOCOUNT ON
DECLARE @agentid INT, @roleid TINYINT, @IsInternal BIT, @IsAdminCanViewVNIP BIT

SELECT @roleid = roleid, @agentid = recommend
FROM custinfo WITH (NOLOCK)
WHERE custid = @CustID
--Get Internal status
SELECT @IsInternal = CASE @roleid WHEN 4 THEN (SELECT isnull(IsInternal, 0) FROM custSuper WITH (NOLOCK) WHERE custid = @custid)
								  WHEN 3 THEN (SELECT isnull(IsInternal, 0) FROM custMaster WITH (NOLOCK) WHERE custid = @custid)
								  WHEN 2 THEN (SELECT isnull(IsInternal, 0) FROM custAgent WITH (NOLOCK) WHERE custid = @custid)
								  WHEN 1 THEN (SELECT isnull(IsInternal, 0) FROM custAgent WITH (NOLOCK) WHERE custid = @agentid)
								  ELSE 0 END 

SELECT @IsAdminCanViewVNIP = 1
IF (@AdminID > 0) 
BEGIN
	DECLARE @ErrCode INT
	EXEC DB03.bodb02.dbo.Acc_Con_CheckPermission_All @custid=@AdminID,@funcname='[ViewIPVN]',@ErrCode=@ErrCode OUTPUT
	IF @ErrCode<> 0 SELECT @IsAdminCanViewVNIP = 0 ELSE SELECT @IsAdminCanViewVNIP = 1     
END

SELECT --ISNULL(reject,0) AS Suspend,
		ISNULL (closed,0) As Closed,
		ISNULL (autosuspend,0) As AutoSuspend,	
		ISNULL (cm.DisableAutoMPT ,0) As DisableAutoMPT,	
		ISNULL(DisableHorseracing,0) AS DisableHorseracing,
		ISNULL(DisableOpenTote,0) AS DisableOpenTote,
		ISNULL(DisableFinancial,0) AS DisableFI,
		ISNULL(SyncCasino,0) AS SyncCasino,
		ISNULL(DisableCasino,0) AS DisableCasino,
		--ISNULL(SyncLiveCasino,0) AS SyncLiveCasino,
		ISNULL(DisableLiveCasino,0) AS DisableLiveCasino,
		ISNULL(DisableOutright,0) AS DisableOutright,
		ISNULL(srecommend, 0) AS SRecommend,
		ISNULL(mrecommend, 0) AS MRecommend,
		ISNULL(recommend, 0) as ARecommend,
		ISNULL(@IsAdminCanViewVNIP,1) AS IsAdminCanViewVNIP,
		@IsInternal AS IsInternal
FROM custinfo AS ci WITH (nolock)
	LEFT JOIN CustMaster AS cm WITH (NOLOCK) ON ci.CustID = cm.custid
WHERE ci.CustID = @CustID


GO
